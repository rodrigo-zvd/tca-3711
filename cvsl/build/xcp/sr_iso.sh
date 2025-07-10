#!/bin/bash

# This script automates several tasks on an XCP-ng host:
# In 'create' mode:
# 1. Creates a specified directory.
# 2. Downloads a file (e.g., an ISO) into that directory.
# 3. Creates an ISO Storage Repository (SR).
# In 'destroy' mode:
# 1. Removes the created ISO Storage Repository (SR).
# 2. Removes the created directory.
#
# Designed to be called by another script, which will export the necessary
# configuration variables as environment variables.

# Exit immediately if a command exits with a non-zero status, unless specifically handled.
set -e

# --- EXPECTED ENVIRONMENT VARIABLES (No default values here) ---
# XCP_NG_HOST             # XCP-ng Host IP address or hostname
# XCP_NG_USER             # XCP-ng User (e.g., 'root')
# XCP_NG_PASSWORD         # XCP-ng Password (Be cautious with storing passwords directly in scripts!)
# XCP_NG_UNATTENDED_INSTALL_ISO_NAME # Name of the ISO file (e.g., "xcp-ng-8.3.0-unattended-install.iso") expected in the local 'isos/' directory
# XCP_NG_SR_ISO_NAME      # Name for the new ISO Storage Repository on XCP-ng host
# XCP_NG_SR_ISO_PATH      # Path on the XCP-ng host where the ISO will be stored and the SR will be created

# =======================================================
#                      Functions
# =======================================================

# Function to execute a command on the remote XCP-ng host and capture its output
# This version returns the exit status of the remote command, allowing for more flexible error handling.
execute_remote_command() {
    local command="$1"
    local output_var_name="${2:-_remote_command_output}" # Optional: name of variable to store output
    echo "Executing command on ${XCP_NG_HOST}: ${command}" >&2 # Redirect to stderr to not pollute stdout

    local output
    output=$(sshpass -p "${XCP_NG_PASSWORD}" ssh -o StrictHostKeyChecking=no "${XCP_NG_USER}@${XCP_NG_HOST}" "${command}" 2>&1)
    local status=$?

    # Store output in the specified variable name, or a default one
    eval "${output_var_name}=\"$output\""

    return ${status}
}

# Function to create resources (directory, download file, create SR)
create_resources() {
    echo "Starting XCP-ng automation script in 'create' mode..."

    # Define local ISO path
    local_iso_source_path="isos/${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}"

    # Validate if the local ISO file exists
    if [ ! -f "${local_iso_source_path}" ]; then
        echo "ERROR: Local ISO file not found: ${local_iso_source_path}" >&2
        echo "Please ensure the ISO exists in the 'isos/' directory or download it first." >&2
        exit 1
    fi

    # Calculate SHA256 of the local source ISO file
    echo "Calculating SHA256 checksum for local ISO: ${local_iso_source_path}..."
    LOCAL_SOURCE_SHA256=$(sha256sum "${local_iso_source_path}" | awk '{print $1}')
    echo "Local ISO SHA256: ${LOCAL_SOURCE_SHA256}"

    # Task 1: Create the directory specified by XCP_NG_SR_ISO_PATH on XCP_NG_HOST
    echo "Task 1/3: Creating directory '${XCP_NG_SR_ISO_PATH}' on ${XCP_NG_HOST}..."
    execute_remote_command "mkdir -p ${XCP_NG_SR_ISO_PATH}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create directory '${XCP_NG_SR_ISO_PATH}' on ${XCP_NG_HOST}. Exiting." >&2
        exit 1
    fi
    echo "Directory created successfully."

    # Task 2: Check and transfer the ISO to XCP_NG_SR_ISO_PATH on XCP_NG_HOST
    echo "Task 2/3: Checking and transferring '${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}' to '${XCP_NG_SR_ISO_PATH}' on ${XCP_NG_HOST}..."

    TARGET_ISO_PATH="${XCP_NG_SR_ISO_PATH}/${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}"
    TRANSFER_NEEDED=true
    local _remote_file_check_output # Declare variable for output

    # Execute the file check command and capture its exit status
    if execute_remote_command "[ -f \"${TARGET_ISO_PATH}\" ]" "_remote_file_check_output"; then
        echo "  - Found existing file '${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}' at '${TARGET_ISO_PATH}' on ${XCP_NG_HOST}. Verifying SHA256..."

        # Calculate SHA256 of the existing file on the remote host
        local REMOTE_ACTUAL_CHECKSUM_OUTPUT
        execute_remote_command "sha256sum \"${TARGET_ISO_PATH}\" | awk '{print \$1}'" "REMOTE_ACTUAL_CHECKSUM_OUTPUT"
        local REMOTE_ACTUAL_CHECKSUM=$(echo "$REMOTE_ACTUAL_CHECKSUM_OUTPUT" | tr -d '\n\r ') # Clean potential whitespace

        if [ "$LOCAL_SOURCE_SHA256" == "$REMOTE_ACTUAL_CHECKSUM" ]; then
            echo "  - Existing remote file SHA256 matches local source checksum. Skipping transfer."
            TRANSFER_NEEDED=false
        else
            echo "  - Remote file SHA256 MISMATCH. Local Expected: $LOCAL_SOURCE_SHA256, Remote Got: $REMOTE_ACTUAL_CHECKSUM." >&2
            echo "  - Removing existing remote file and proceeding with transfer." >&2
            execute_remote_command "rm \"${TARGET_ISO_PATH}\""
            if [ $? -ne 0 ]; then
                echo "Error: Failed to remove existing remote ISO. Exiting." >&2
                exit 1
            fi
        fi
    else
        echo "  - File '${XCP_NG_UNATTENDED_INSTALL_ISO_NAME}' not found at '${TARGET_ISO_PATH}' on ${XCP_NG_HOST}."
        # No need to remove if it doesn't exist, TRANSFER_NEEDED remains true
    fi

    if [ "$TRANSFER_NEEDED" = true ]; then
        echo "  - Transferring local ISO '${local_iso_source_path}' to '${TARGET_ISO_PATH}' on ${XCP_NG_HOST}..."
        # scp does not use the execute_remote_command function as it's a direct file transfer
        sshpass -p "${XCP_NG_PASSWORD}" scp -o StrictHostKeyChecking=no "${local_iso_source_path}" "${XCP_NG_USER}@${XCP_NG_HOST}:${TARGET_ISO_PATH}" 2>&1 >&2 # Redirect scp output
        TRANSFER_STATUS=$?

        if [ $TRANSFER_STATUS -ne 0 ]; then
            echo "Error: Failed to transfer ISO to ${XCP_NG_HOST}. Check SSH connectivity, permissions, and disk space." >&2
            exit 1
        fi
        echo "  - File transferred successfully to ${XCP_NG_HOST}."
    else
        echo "  - Skipping file transfer as file already exists and checksum matches."
    fi

    echo "File check and transfer completed."

    # Task 3: Check and create a Storage Repository (SR) on XCP_NG_HOST
    echo "Task 3/3: Checking and creating Storage Repository '${XCP_NG_SR_ISO_NAME}' on ${XCP_NG_HOST}..."

    local SR_LIST_OUTPUT
    execute_remote_command "xe sr-list name-label=\"${XCP_NG_SR_ISO_NAME}\" --minimal" "SR_LIST_OUTPUT"
    local SR_LIST_STATUS=$?

    SR_UUID=""
    if [ ${SR_LIST_STATUS} -eq 0 ] && [ -n "${SR_LIST_OUTPUT}" ]; then
        # Parse the UUID from the output, handling different formats
        if echo "${SR_LIST_OUTPUT}" | grep -q "uuid (RO)"; then
            SR_UUID=$(echo "${SR_LIST_OUTPUT}" | grep "uuid (RO)" | awk '{print $NF}' | tr -d '\n\r ')
        else # Assume it's the UUID directly from --minimal
            SR_UUID=$(echo "${SR_LIST_OUTPUT}" | tr -d '\n\r ')
        fi
    fi

    if [ -n "${SR_UUID}" ]; then
        echo "Storage Repository '${XCP_NG_SR_ISO_NAME}' (UUID: ${SR_UUID}) already exists. Attempting to destroy and recreate it." >&2

        # Temporarily disable set -e for this block to ensure cleanup attempts even if one fails
        set +e
        echo "  Unplugging PBDs for SR ${SR_UUID}..."
        local PBD_LIST_OUTPUT
        execute_remote_command "xe pbd-list sr-uuid=${SR_UUID} --minimal" "PBD_LIST_OUTPUT"
        local PBD_UUIDS=$(echo "${PBD_LIST_OUTPUT}" | tr ' ' '\n' | grep -v '^$' | sort -u)
        if [ -n "${PBD_UUIDS}" ]; then
            for PBD_UUID in ${PBD_UUIDS}; do
                echo "  Unplugging PBD: ${PBD_UUID}..."
                execute_remote_command "xe pbd-unplug uuid=${PBD_UUID}"
            done
        fi
        echo "  Forgetting SR ${SR_UUID}..."
        execute_remote_command "xe sr-forget uuid=${SR_UUID}"
        set -e # Re-enable set -e

        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to destroy existing SR '${XCP_NG_SR_ISO_NAME}' (UUID: ${SR_UUID}). Please destroy it manually on your XCP-ng host." >&2
            echo "  Run: xe sr-forget uuid=${SR_UUID}" >&2
            exit 1
        fi
        echo "Existing SR '${XCP_NG_SR_ISO_NAME}' destroyed. Proceeding with recreation."
    fi

    # Create the Storage Repository (this block will always run if SR was not found or was just destroyed)
    echo "Storage Repository '${XCP_NG_SR_ISO_NAME}' does not exist or was just destroyed. Creating it now..."
    SR_COMMAND="xe sr-create name-label=\"${XCP_NG_SR_ISO_NAME}\" type=iso device-config:location=${XCP_NG_SR_ISO_PATH} device-config:legacy_mode=true content-type=iso"
    execute_remote_command "${SR_COMMAND}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create Storage Repository '${XCP_NG_SR_ISO_NAME}'. Exiting." >&2
        exit 1
    fi
    echo "Storage Repository created successfully."

    echo "XCP-ng automation script in 'create' mode completed."
}

# Function to destroy resources (SR, directory)
destroy_resources() {
    echo "Starting XCP-ng automation script in 'destroy' mode..."

    # Task 1: Remove the SR created by the 'create' mode
    echo "Task 1/2: Removing Storage Repository '${XCP_NG_SR_ISO_NAME}' on ${XCP_NG_HOST}..."

    local SR_UUID_OUTPUT
    execute_remote_command "xe sr-list name-label=\"${XCP_NG_SR_ISO_NAME}\" --minimal" "SR_UUID_OUTPUT"
    local SR_UUID_STATUS=$?

    SR_UUID=""
    if [ ${SR_UUID_STATUS} -eq 0 ] && [ -n "${SR_UUID_OUTPUT}" ]; then
        if echo "${SR_UUID_OUTPUT}" | grep -q "uuid (RO)"; then
            SR_UUID=$(echo "${SR_UUID_OUTPUT}" | grep "uuid (RO)" | awk '{print $NF}' | tr -d '\n\r ')
        else
            SR_UUID=$(echo "${SR_UUID_OUTPUT}" | tr -d '\n\r ')
        fi
    fi

    if [ -n "${SR_UUID}" ]; then
        echo "Found Storage Repository '${XCP_NG_SR_ISO_NAME}' with UUID: ${SR_UUID}."

        # Find and unplug any PBDs connected to this SR
        echo "Searching for PBDs connected to SR ${SR_UUID}..."
        local PBD_LIST_OUTPUT
        execute_remote_command "xe pbd-list sr-uuid=${SR_UUID} --minimal" "PBD_LIST_OUTPUT"
        local PBD_LIST_STATUS=$?

        PBD_UUIDS=""
        if [ ${PBD_LIST_STATUS} -eq 0 ] && [ -n "${PBD_LIST_OUTPUT}" ]; then
            PBD_UUIDS=$(echo "${PBD_LIST_OUTPUT}" | tr ' ' '\n' | grep -v '^$' | sort -u) # Handle multiple PBDs
        fi

        if [ -n "${PBD_UUIDS}" ]; then
            for PBD_UUID in ${PBD_UUIDS}; do
                echo "Found PBD: ${PBD_UUID}. Attempting to unplug it..."
                execute_remote_command "xe pbd-unplug uuid=${PBD_UUID}"
                if [ $? -ne 0 ]; then
                    echo "Error: Failed to unplug PBD ${PBD_UUID}. Exiting." >&2
                    exit 1
                fi
                echo "PBD ${PBD_UUID} unplugged."
            done
        else
            echo "No PBDs found for SR ${SR_UUID} or they are already unplugged."
        fi

        echo "Attempting to forget SR ${SR_UUID}..."
        execute_remote_command "xe sr-forget uuid=${SR_UUID}"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to forget SR ${SR_UUID}. Exiting." >&2
            exit 1
        fi
        echo "Storage Repository forgotten successfully."
    else
        echo "Storage Repository '${XCP_NG_SR_ISO_NAME}' not found. Skipping SR removal."
    fi

    # Task 2: Remove the directory created in 'create' mode
    echo "Task 2/2: Removing directory '${XCP_NG_SR_ISO_PATH}' on ${XCP_NG_HOST}..."
    execute_remote_command "rm -rf ${XCP_NG_SR_ISO_PATH}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to remove directory '${XCP_NG_SR_ISO_PATH}'. Exiting." >&2
        exit 1
    fi
    echo "Directory removed successfully."

    echo "XCP-ng automation script in 'destroy' mode completed."
}

# =======================================================
#                      Main Logic
# =======================================================

# Validate mandatory environment variables
# This block ensures that all necessary variables are set before proceeding.
# If any are missing, the script will exit with an error.
if [ -z "$XCP_NG_HOST" ]; then
    echo "ERROR: Environment variable XCP_NG_HOST is not set." >&2
    exit 1
fi
if [ -z "$XCP_NG_USER" ]; then
    echo "ERROR: Environment variable XCP_NG_USER is not set." >&2
    exit 1
fi
if [ -z "$XCP_NG_PASSWORD" ]; then
    echo "ERROR: Environment variable XCP_NG_PASSWORD is not set." >&2
    echo "WARNING: Storing passwords directly in scripts is insecure. Consider SSH keys for production." >&2
    exit 1
fi
if [ -z "$XCP_NG_UNATTENDED_INSTALL_ISO_NAME" ]; then
    echo "ERROR: Environment variable XCP_NG_UNATTENDED_INSTALL_ISO_NAME is not set." >&2
    echo "Please set this variable with the filename of the ISO (e.g., 'xcp-ng-8.3.0-unattended-install.iso')." >&2
    exit 1
fi
if [ -z "$XCP_NG_SR_ISO_NAME" ]; then
    echo "ERROR: Environment variable XCP_NG_SR_ISO_NAME is not set." >&2
    exit 1
fi
if [ -z "$XCP_NG_SR_ISO_PATH" ]; then
    echo "ERROR: Environment variable XCP_NG_SR_ISO_PATH is not set." >&2
    exit 1
fi


# Check for the mode argument (create|destroy)
if [ -z "$1" ]; then
    echo "Usage: $0 [create|destroy]" >&2
    exit 1
fi

MODE="$1"

case "${MODE}" in
    create)
        create_resources
        ;;
    destroy)
        destroy_resources
        ;;
    *)
        echo "Invalid mode: ${MODE}" >&2
        echo "Usage: $0 [create|destroy]" >&2
        exit 1
        ;;
esac