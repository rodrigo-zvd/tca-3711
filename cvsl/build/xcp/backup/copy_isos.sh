#!/bin/bash

# Script to copy ISO files to an XCP-ng host and configure/scan a local ISO Storage Repository (SR).
# This script uses rsync for efficient file transfers, displays progress, and performs necessary validations.

# Ensures that the script exits immediately if any command fails.
set -e

# --- Configuration (ADJUST THESE VALUES!) ---
# Make sure these values are correct for your environment.
XCP_USER="root"
XCPNG_HOST="192.168.1.10"
XCPNG_PASSWORD="megaFox50" # CAUTION: Password exposed in the script. Consider using SSH keys!

# Local path on your machine (where this script is executed)
# where your ISO files are located.
LOCAL_ISO_DIR="./isos"

# Path on the XCP-ng host where ISOs will be stored and which will be the
# 'device-config:location' for the ISO Storage Repository (SR).
# /iso is a non-standard directory. It's usually something like /var/opt/xen/iso_sr_name
XCPNG_REMOTE_ISO_PATH="/iso-xcp"

# Name to be given to the ISO Storage Repository (SR) in XCP-ng.
ISO_SR_NAME="XCP ISO"

# --- Helper Functions ---

# Function to display an error message and exit the script
error_exit() {
    echo "$(date): ERROR: $1" >&2
    exit 1
}

# Function to execute a command via SSH on the XCP-ng host
# Redirects stdout and stderr to the local script's output to show progress/errors.
run_remote_command() {
    local command="$1"
    echo "$(date): [XCP-ng] Executing: $command"
    sshpass -p "$XCPNG_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$XCP_USER@$XCPNG_HOST" "$command"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        return $exit_code # Return the exit code of the remote command
    fi
    return 0
}

# --- Main Script Start ---
echo "$(date): Script started. Performing environment checks..."

# 1. Check for 'sshpass' and 'rsync' installation
echo "$(date): Checking dependencies: 'sshpass' and 'rsync'..."
if ! command -v sshpass &> /dev/null; then
    error_exit "The 'sshpass' command was not found. Please install it.
    Installation suggestions:
    - Debian/Ubuntu: sudo apt-get install sshpass
    - CentOS/RHEL: sudo yum install sshpass"
fi
if ! command -v rsync &> /dev/null; then
    error_exit "The 'rsync' command was not found. Please install it.
    Installation suggestions:
    - Debian/Ubuntu: sudo apt-get install rsync
    - CentOS/RHEL: sudo yum install rsync"
fi
echo "$(date): 'sshpass' and 'rsync' found."


# 2. Check the local ISOs directory
echo "$(date): Checking local ISOs directory: '$LOCAL_ISO_DIR'..."
if [ ! -d "$LOCAL_ISO_DIR" ]; then
    error_exit "The specified local ISOs directory '$LOCAL_ISO_DIR' does not exist. Please create it and place your ISOs there."
fi

LOCAL_ISO_FILES=("$LOCAL_ISO_DIR"/*.iso) # Captures only .iso files
if [ "${#LOCAL_ISO_FILES[@]}" -eq 0 ] || [ ! -e "${LOCAL_ISO_FILES[0]}" ]; then
    echo "$(date): WARNING: The local ISOs directory '$LOCAL_ISO_DIR' does not contain any .iso files. No ISOs will be copied."
    NO_ISOS_TO_COPY=true
else
    echo "$(date): Found ${#LOCAL_ISO_FILES[@]} ISO files in directory '$LOCAL_ISO_DIR'."
    NO_ISOS_TO_COPY=false
fi

echo ""
echo "$(date): --- PREPARING XCP-ng HOST REMOTELY ---"
echo "$(date): Connecting to $XCPNG_HOST as $XCP_USER..."
echo "$(date): WARNING: Using password on the command line via 'sshpass' (less secure). Consider SSH keys."
echo "$(date): WARNING: SSH host key checking is disabled ('StrictHostKeyChecking=no')."

# Attempt a basic connection to verify reachability
run_remote_command "echo 'SSH connection successful to XCP-ng host.'" || error_exit "Could not connect to XCP-ng host. Check IP, credentials, and firewall."

echo "$(date): Creating/verifying remote directory '$XCPNG_REMOTE_ISO_PATH' on XCP-ng host..."
run_remote_command "mkdir -p \"$XCPNG_REMOTE_ISO_PATH\" && chmod 755 \"$XCPNG_REMOTE_ISO_PATH\"" || \
    error_exit "Failed to create or verify the remote directory on XCP-ng."
echo "$(date): Remote directory created/verified."

echo ""
if [ "$NO_ISOS_TO_COPY" = false ]; then
    echo "$(date): --- COPYING ISO FILES TO XCP-ng using rsync ---"
    echo "$(date): Copying from '$LOCAL_ISO_DIR' to '$XCPNG_HOST:$XCPNG_REMOTE_ISO_PATH'..."
    echo "$(date): 'rsync' will display copy progress. This might take a while for large files."

    # Copy ISO files using rsync
    # -a: archive mode (recursive, preserves symlinks, permissions, times, group, owner)
    # -h: human-readable numbers
    # --info=progress2: overall progress bar for all files
    # -e: specifies the remote shell to use (here, ssh with required options)
    sshpass -p "$XCPNG_PASSWORD" rsync -avh --info=progress2 \
        -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        "$LOCAL_ISO_DIR"/*.iso "$XCP_USER@$XCPNG_HOST:$XCPNG_REMOTE_ISO_PATH" || \
        error_exit "Failed to copy ISO files to XCP-ng host using rsync. Check path and permissions."
    echo "$(date): ISO files copied successfully."
else
    echo "$(date): No ISOs to copy. Skipping file copy step."
fi

echo ""
# echo "$(date): --- CONFIGURING ISO SR ON XCP-ng ---"

# # 3. Check and create/scan ISO SR
# echo "$(date): Checking if ISO SR '$ISO_SR_NAME' already exists on the XCP-ng host..."
# SR_UUID=$(run_remote_command "xe sr-list name-label=\"$ISO_SR_NAME\" | grep uuid | cut -d: -f2 | xargs")
# LAST_COMMAND_EXIT_CODE=$? # Capture the exit code of the last run_remote_command

# # If the remote command completely failed (e.g., xe not found), handle it here
# if [ $LAST_COMMAND_EXIT_CODE -ne 0 ] && [ -z "$SR_UUID" ]; then
#     error_exit "Failed to query SRs on XCP-ng (xe command might not be available or connection error)."
# fi

# if [ -n "$SR_UUID" ]; then
#     echo "$(date): ISO SR '$ISO_SR_NAME' not found. Creating new SR..."
#     # SR creation points to the directory where ISOs were copied.
#     SR_UUID=$(run_remote_command "xe sr-create name-label=\"$ISO_SR_NAME\" type=iso device-config:location=\"$XCPNG_REMOTE_ISO_PATH\" device-config:legacy_mode=true content-type=iso") || \
#        error_exit "Failed to create ISO SR '$ISO_SR_NAME'. Check permissions on the remote directory and if the SR already exists with a different name/type."
#     echo "$(date): ISO SR '$ISO_SR_NAME' created with UUID: $SR_UUID."
# else
#     echo "$(date): ISO SR '$ISO_SR_NAME' already exists with UUID: $SR_UUID."
#     # Optional: Validate if 'device-config:location' is the same.
#     # current_location=$(run_remote_command "xe sr-param-get uuid=$SR_UUID param-name=device-config param-key=location")
#     # if [ "$current_location" != "$XCPNG_REMOTE_ISO_PATH" ]; then
#     #     echo "$(date): WARNING: The existing SR '$ISO_SR_NAME' points to a different location: $current_location.
#     #     ISOs copied to $XCPNG_REMOTE_ISO_PATH might not be detected by this SR.
#     #     Consider renaming the existing SR or adjusting the path."
#     # fi
# fi

# echo "$(date): Scanning ISO SR '$ISO_SR_NAME' (UUID: $SR_UUID) to detect new ISOs..."
# run_remote_command "xe sr-scan uuid=\"$SR_UUID\"" || \
#     echo "$(date): WARNING: Failed to scan ISO SR '$ISO_SR_NAME'. Please verify manually in XCP-ng Center/XO if the ISOs appeared."
# echo "$(date): ISO SR scanned."

# echo ""
# echo "$(date): Script completed. Please check SR '$ISO_SR_NAME' on your XCP-ng host to confirm the ISOs."
# echo "$(date): You can list the ISOs with: ssh $XCP_USER@$XCPNG_HOST 'xe cd-list'"

exit 0