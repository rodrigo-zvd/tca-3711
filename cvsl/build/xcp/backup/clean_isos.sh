#!/bin/bash

# Script to clean up the ISO Storage Repository (SR) and its directory
# created by the XCP-ng ISO management script.
# This version DOES NOT ask for confirmation before proceeding.

# Ensures that the script exits immediately if any command fails.
set -e

# --- Configuration (MUST MATCH PREVIOUS SCRIPT!) ---
# Adjust these values to match your XCP-ng environment and the previous script's settings.
XCP_USER="root"
XCPNG_HOST="192.168.1.10"
XCPNG_PASSWORD="megaFox50" # CAUTION: Password exposed in the script. Consider using SSH keys!

# Path on the XCP-ng host where ISOs were stored and the SR pointed to.
XCPNG_REMOTE_ISO_PATH="/iso-xcp"

# Name of the ISO Storage Repository (SR) to be removed.
ISO_SR_NAME="XCP ISO" # Must match the name used in the creation script!

# --- Helper Functions ---

# Function to display an error message and exit the script
error_exit() {
    echo "$(date): ERROR: $1" >&2
    exit 1
}

# Function to execute a command via SSH on the XCP-ng host
# It prints stdout/stderr of the remote command and returns its exit code.
run_remote_command() {
    local command="$1"
    echo "$(date): [XCP-ng] Executing: $command"
    # Execute the command remotely. The 'ssh' client's exit code will reflect
    # the remote command's exit code, or 255 for SSH connection errors.
    sshpass -p "$XCPNG_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "$XCP_USER@$XCPNG_HOST" "$command"
    local exit_code=$?
    # If SSH itself fails (e.g., connection refused, auth error), exit code is 255.
    if [ "$exit_code" -eq 255 ]; then
        error_exit "SSH connection failed to $XCPNG_HOST. Check connectivity or credentials."
    fi
    return "$exit_code" # Return the actual exit code of the remote command (via ssh's exit status)
}

# --- Main Script Start ---
echo "$(date): Script started. Preparing to clean up XCP-ng resources."

# 1. Check for 'sshpass' installation
echo "$(date): Checking dependency: 'sshpass'..."
if ! command -v sshpass &> /dev/null; then
    error_exit "The 'sshpass' command was not found. Please install it."
fi
echo "$(date): 'sshpass' found."

echo ""
echo "$(date): --- CONNECTING TO XCP-ng HOST ---"
echo "$(date): Connecting to $XCPNG_HOST as $XCP_USER..."
echo "$(date): WARNING: Using password on the command line via 'sshpass' (less secure). Consider SSH keys!"
echo "$(date): WARNING: SSH host key checking is disabled ('StrictHostKeyChecking=no')."

# Attempt a basic connection to verify reachability
run_remote_command "echo 'SSH connection successful to XCP-ng host.'" || error_exit "Could not connect to XCP-ng host. Check IP, credentials, and firewall."
echo "$(date): Basic SSH connectivity confirmed."

echo ""
echo "$(date): --- PROCEEDING WITH CLEANUP (NO CONFIRMATION ASKED) ---"
echo "--------------------------------------------------------------------------"
echo "ATTENTION: This script will immediately attempt to remove the SR"
echo "'$ISO_SR_NAME' and delete the directory '$XCPNG_REMOTE_ISO_PATH'"
echo "on the XCP-ng host: '$XCPNG_HOST'."
echo "--------------------------------------------------------------------------"
sleep 3 # Give a moment for the user to read the warning.

# 2. Find and forget the SR
echo "$(date): Attempting to find SR '$ISO_SR_NAME' to forget..."
# The output of run_remote_command needs to be captured to get the UUID,
# and its exit status for checking if the SR was actually found.
TEMP_SR_UUID=$(run_remote_command "xe sr-list name-label=\"$ISO_SR_NAME\" | grep uuid | cut -d: -f2 | xargs")
LAST_CMD_STATUS=$? # Capture the exit code of the run_remote_command call

# Check if the SR_UUID was found based on output and exit status
if [ -z "$TEMP_SR_UUID" ]; then
    if [ "$LAST_CMD_STATUS" -ne 0 ]; then
        echo "$(date): SR '$ISO_SR_NAME' not found (xe command returned non-zero status). Nothing to forget."
    else
        echo "$(date): WARNING: 'xe sr-list' returned empty output but indicated success. Assuming SR '$ISO_SR_NAME' not found. Nothing to forget."
    fi
else
    SR_UUID="$TEMP_SR_UUID"
    echo "$(date): SR '$ISO_SR_NAME' found with UUID: $SR_UUID. Attempting to forget SR..."
    run_remote_command "xe sr-forget uuid=\"$SR_UUID\"" || \
        echo "$(date): WARNING: Failed to forget SR '$ISO_SR_NAME' (UUID: $SR_UUID). It might already be forgotten or still in use by a VM/object. Please check manually in XenCenter/XenOrchestra."
    echo "$(date): SR forget command sent. Verify its status on XCP-ng host."
fi

# 3. Delete the remote ISO directory
echo "$(date): Checking if remote directory '$XCPNG_REMOTE_ISO_PATH' exists for deletion..."
# Test if the directory exists on the remote host. 'test -d' returns 0 if true, 1 if false.
run_remote_command "test -d \"$XCPNG_REMOTE_ISO_PATH\""
DIR_EXISTS=$? 

if [ "$DIR_EXISTS" -eq 0 ]; then
    echo "$(date): Directory '$XCPNG_REMOTE_ISO_PATH' found. Attempting to delete..."
    run_remote_command "rm -rf \"$XCPNG_REMOTE_ISO_PATH\"" || \
        error_exit "Failed to delete remote directory '$XCPNG_REMOTE_ISO_PATH'. Check permissions on $XCPNG_HOST."
    echo "$(date): Remote directory '$XCPNG_REMOTE_ISO_PATH' deleted successfully."
else
    echo "$(date): Remote directory '$XCPNG_REMOTE_ISO_PATH' not found. Nothing to delete."
fi

echo ""
echo "$(date): Cleanup script completed. Please verify on your XCP-ng host that the SR and directory are gone."
echo "$(date): You can re-check with: ssh $XCP_USER@$XCPNG_HOST 'xe sr-list' and 'ls -ld $XCPNG_REMOTE_ISO_PATH'"

exit 0