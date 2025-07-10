#!/bin/bash

# Script to create and configure the cloud-init boot script on the remote XCP-ng host.
# This script is executed on your controller machine (e.g., workstation, automation server).

# --- SSH Access Configuration for XCP-ng Host ---
# IMPORTANT: Update these variables for your environment!
XCPNG_HOST="192.168.1.49" # <--- Change to your XCP-ng host's IP/Hostname
SSH_USER="root"                      # <--- SSH user for the XCP-ng host (usually 'root')
SSH_PASSWORD="123456"   # <--- UNCOMMENT and fill if using password (NOT RECOMMENDED for automation)
# SSH_KEY="/home/rodrigo/.ssh/id_rsa"  # <--- Change to the path of your private SSH key (RECOMMENDED)

# --- File Paths on the Nested XCP-ng VM (where the boot script and setup script will reside) ---
REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH="/usr/local/bin/cloud_init_boot_config.sh"
REMOTE_XCPNG_SETUP_SCRIPT_PATH="/usr/local/bin/xcp-ng-setup.sh"
REMOTE_SERVICE_PATH="/etc/systemd/system/cloud-init-boot.service"
REMOTE_MARKER_FILE="/var/run/cloud_init_boot_complete"

# --- Functions ---

# Function to execute commands via SSH, optionally piping content to stdin
execute_remote() {
    local cmd="$1"
    local stdin_content="${2:-}" # Optional second argument for stdin content

    echo "Executing remotely on $XCPNG_HOST: $cmd"

    local ssh_command_options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" # Ignores known_hosts completely for automation

    local ssh_command
    if [[ -n "$SSH_PASSWORD" ]]; then
        # Using sshpass for password authentication (requires 'sshpass' package)
        # Ensure sshpass is installed on the controller machine.
        if ! command -v sshpass &> /dev/null; then
            echo "ERROR: 'sshpass' not found. Please install it or use SSH keys." >&2
            exit 1
        fi
        ssh_command="sshpass -p \"$SSH_PASSWORD\" ssh $ssh_command_options \"$SSH_USER@$XCPNG_HOST\""
    elif [[ -n "$SSH_KEY" ]]; then
        # SSH key authentication (recommended)
        ssh_command="ssh -i \"$SSH_KEY\" $ssh_command_options \"$SSH_USER@$XCPNG_HOST\""
    else
        echo "ERROR: No SSH authentication method (password or key) provided." >&2
        exit 1
    fi

    if [[ -n "$stdin_content" ]]; then
        # Use a here-string to pipe content to the remote command
        eval "$ssh_command \"$cmd\"" <<< "$stdin_content"
    else
        # Execute command directly
        eval "$ssh_command \"$cmd\""
    fi

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to execute remote command on $XCPNG_HOST. Script will exit." >&2
        exit 1
    fi
}

# --- Original xcp_ng_setup_script.sh content (will be modified below) ---
# Read the original script content
XCP_NG_SETUP_SCRIPT_ORIGINAL_CONTENT=$(<xcp_ng_setup_script.sh)

# --- Modify xcp_ng_setup_script.sh content for cloud-init integration ---
# 1. Modify CONFIG_FILE to accept the path as the first argument
# 2. Add a check to ensure the argument is provided if CONFIG_FILE is not implicitly defined.
XCP_NG_SETUP_SCRIPT_MODIFIED_CONTENT=$(cat << EOF_XCP_SETUP
#!/bin/bash

# Script to configure an XCP-ng host, including network settings, hostname,
# user management, SSH keys, and timezone.
# This script is designed for automated (non-interactive) execution.

# Set -e ensures that the script exits immediately if any command fails.
set -e

# --- Import Configuration Variables ---
# The path to the configuration file is expected as the first argument.
# If no argument is provided, it defaults to './config-variables.sh' (for standalone testing).
CONFIG_FILE="\$1"

if [ -z "\$CONFIG_FILE" ]; then
    echo "\$(date): WARNING: No configuration file path provided as argument. Using default './config-variables.sh'."
    CONFIG_FILE="./config-variables.sh"
fi

if [ ! -f "\$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file '\$CONFIG_FILE' not found!"
    echo "Please ensure the config file exists at the specified path."
    exit 1
fi

echo "\$(date): Loading configuration from '\$CONFIG_FILE'..."
source "\$CONFIG_FILE"
echo "\$(date): Configuration loaded successfully."

# --- Initial Diagnostic Output ---
echo "\$(date): Script started. Performing initial environment checks."
# Ensure stderr is also captured by Terraform for early errors
exec 2>&1

# --- HELPER FUNCTIONS ---

# Function to display an error message and exit
error_exit() {
    echo "ERROR: \$1" >&2
    exit 1
}

# Function to validate basic IP format
validate_ip() {
    local ip=\$1
    if [[ \$ip =~ ^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\$ ]]; then
        IFS='.' read -r -a octets <<< "\$ip"
        for octet in "\${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to add SSH keys for a given user
# Args: \$1=username, \$2=home_directory, \$3=public_keys_content
add_ssh_keys_for_user() {
    local user_name="\$1"
    local home_dir="\$2"
    local public_keys="\$3"

    if [ -z "\$public_keys" ]; then
        echo "\$(date): WARNING: No public keys provided for user '\$user_name'. Skipping key addition."
        return 0
    fi

    echo "\$(date): Adding SSH keys for user '\$user_name' in '\$home_dir/.ssh'..."
    local ssh_dir="\${home_dir}/.ssh"
    local authorized_keys_file="\${ssh_dir}/authorized_keys"

    mkdir -p "\$ssh_dir" || error_exit "Failed to create SSH directory for '\$user_name'."
    chmod 700 "\$ssh_dir" || error_exit "Failed to set permissions on SSH directory '\$ssh_dir'."

    # Set ownership for the .ssh directory immediately
    # This is important if creating for a non-root user
    if [ "\$user_name" != "root" ]; then
        chown "\$user_name":"\$user_name" "\$ssh_dir" || echo "\$(date): WARNING: Failed to set ownership for '\$ssh_dir' for user '\$user_name'."
    fi

    # Append keys, making sure to avoid duplicates if re-running script
    # Each key is processed on a new line
    echo "\$public_keys" | while IFS= read -r key_line; do
        # Skip empty lines and comments
        [[ -z "\$key_line" || "\${key_line:0:1}" == "#" ]] && continue
        if ! grep -qF "\$key_line" "\$authorized_keys_file" 2>/dev/null; then
            echo "\$key_line" >> "\$authorized_keys_file"
            echo "\$(date): Added key for '\$user_name': \${key_line%% *}" # Print only the key type and part of the key for brevity
        else
            echo "\$(date): Key already exists for '\$user_name', skipping: \${key_line%% *}"
        fi
    done

    chmod 600 "\$authorized_keys_file" || error_exit "Failed to set permissions on '\$authorized_keys_file'."

    # Set ownership for authorized_keys file
    if [ "\$user_name" != "root" ]; then
        chown "\$user_name":"\$user_name" "\$authorized_keys_file" || echo "\$(date): WARNING: Failed to set ownership for '\$authorized_keys_file' for user '\$user_name'."
    fi

    echo "\$(date): SSH Public Key configuration completed for user '\$user_name'."
}

# --- SCRIPT START ---

echo "\$(date): --- AUTOMATED XCP-ng HOST INITIAL CONFIGURATION ---"
echo ""
echo "CRITICAL WARNINGS:"
if [ "\$CONFIGURE_NETWORK" = "true" ]; then
    echo "1. This script will change the IP address of the XCP-ng host's management interface."
    echo "   SSH/console connectivity to this host may be LOST and re-established on the new IP."
fi
echo "2. It may modify user accounts/passwords and add SSH keys based on configuration."
echo "3. Ensure that ALL Configuration Variables are correct for your environment."
echo "4. It is HIGHLY recommended to have local console access (IPMI/iLO/DRAC) in case of failure."
echo ""

# Validate the defined IPs only if network configuration is enabled
if [ "\$CONFIGURE_NETWORK" = "true" ]; then
    echo "\$(date): Validating network IP and Gateway..."
    validate_ip "\$IP" || error_exit "The IP '\$IP' defined in IP variable is invalid."
    validate_ip "\$GATEWAY" || error_exit "The Gateway '\$GATEWAY' defined in GATEWAY variable is invalid."
    echo "\$(date): Network IP and Gateway validation successful."
fi

echo "\$(date): Checking host UUID..."

# Get the Host UUID
# Added \`|| true\` to prevent \`set -e\` from exiting if xe host-list temporarily fails or gives no output (though it should exist)
HOST_UUID=\$(xe host-list --minimal 2>/dev/null || true)
if [ -z "\$HOST_UUID" ]; then
    # Add a retry loop for host-list as well, as XAPI might still be coming up
    echo "\$(date): Host UUID not found immediately. Retrying..."
    MAX_HOST_UUID_ATTEMPTS=6
    CURRENT_HOST_UUID_ATTEMPT=0
    HOST_UUID_SLEEP_SECONDS=5

    while [ -z "\$HOST_UUID" ] && [ "\$CURRENT_HOST_UUID_ATTEMPT" -lt "\$MAX_HOST_UUID_ATTEMPTS" ]; do
        CURRENT_HOST_UUID_ATTEMPT=\$((CURRENT_HOST_UUID_ATTEMPT + 1))
        echo "\$(date): Attempt \$CURRENT_HOST_UUID_ATTEMPT of \$MAX_HOST_UUID_ATTEMPTS: Running 'xe host-list --minimal'..."
        HOST_UUID=\$(xe host-list --minimal 2>/dev/null || true)
        if [ -z "\$HOST_UUID" ]; then
            echo "\$(date): Host UUID not found yet. Waiting \$HOST_UUID_SLEEP_SECONDS seconds..."
            sleep "\$HOST_UUID_SLEEP_SECONDS"
        fi
    done

    if [ -z "\$HOST_UUID" ]; then
        error_exit "Could not get the host UUID after \$MAX_HOST_UUID_ATTEMPTS attempts. XCP-ng host might not be fully ready or 'xe' command is unavailable."
    fi
fi
echo "\$(date): Host UUID: \$HOST_UUID"

# --- 1. Configure Hostname ---
if [ "\$SET_HOSTNAME" = "true" ]; then
    echo "\$(date): --- Configuring Hostname ---"
    echo "\$(date): Setting host name-label via xe to: \$NEW_HOSTNAME"
    xe host-set-hostname-live host-uuid="\$HOST_UUID" host-name="\$NEW_HOSTNAME" || echo "\$(date): WARNING: Failed to set host name-label via xe. Please check manually."
    # The 'hostnamectl set-hostname' command is typically not necessary on XCP-ng as 'xe host-set-hostname-live' handles the XenServer specific hostname.
    # echo "\$(date): Setting system hostname with hostnamectl to: \$NEW_HOSTNAME"
    # hostnamectl set-hostname "\$NEW_HOSTNAME" || echo "\$(date): WARNING: Failed to set system hostname with hostnamectl. Check logs."
    echo "\$(date): Hostname configuration completed."
else
    echo "\$(date): Skipping hostname configuration as SET_HOSTNAME is 'false'."
fi

# --- 2. User and Password Management ---
echo "\$(date): --- User and Password Management ---"
if [ "\$CREATE_NEW_USER" = "true" ]; then
    if [ -z "\$NEW_SSH_USERNAME" ] || [ -z "\$NEW_USER_PASSWORD" ]; then
        error_exit "NEW_SSH_USERNAME or NEW_USER_PASSWORD is empty when CREATE_NEW_USER is true. Aborting user creation."
    fi

    echo "\$(date): Attempting to create or verify user '\$NEW_SSH_USERNAME'..."
    if id "\$NEW_SSH_USERNAME" &>/dev/null; then
        echo "\$(date): User '\$NEW_SSH_USERNAME' already exists. Updating password."
    else
        useradd -m -s /bin/bash "\$NEW_SSH_USERNAME" || error_exit "Failed to create user '\$NEW_SSH_USERNAME'."
        echo "\$(date): User '\$NEW_SSH_USERNAME' created."
    fi

    echo "\${NEW_SSH_USERNAME}:\${NEW_USER_PASSWORD}" | chpasswd || error_exit "Failed to set password for user '\$NEW_SSH_USERNAME'. Ensure password meets requirements."
    echo "\$(date): Password set for user '\$NEW_SSH_USERNAME'."

    if [ "\$ADD_USER_TO_SUDO_GROUP" = "true" ]; then
        echo "\$(date): Adding user '\$NEW_SSH_USERNAME' to 'wheel' group for sudo access..."
        usermod -aG wheel "\$NEW_SSH_USERNAME" || echo "\$(date): WARNING: Failed to add user '\$NEW_SSH_USERNAME' to 'wheel' group. Manual verification needed for sudo."
        echo "\$(date): User '\$NEW_SSH_USERNAME' added to 'wheel' group."
    fi
else
    echo "\$(date): Skipping new user creation as CREATE_NEW_USER is 'false'."
fi

if [ "\$ROOT_PASSWORD_CHANGE" = "true" ]; then
    if [ -z "\$NEW_ROOT_PASSWORD" ]; then
        error_exit "NEW_ROOT_PASSWORD is empty when ROOT_PASSWORD_CHANGE is true. Aborting root password change."
    fi
    echo "\$(date): Changing root password..."
    echo "root:\${NEW_ROOT_PASSWORD}" | chpasswd || error_exit "Failed to change root password. Ensure password meets requirements."
    echo "\$(date): Root password changed."
else
    echo "\$(date): Skipping root password change as ROOT_PASSWORD_CHANGE is 'false'."
fi

# --- 3. Add SSH Public Keys ---
if [ "\$ADD_SSH_KEYS" = "true" ]; then
    if [ -z "\$SSH_PUBLIC_KEYS" ]; then
        echo "\$(date): WARNING: ADD_SSH_KEYS is 'true' but SSH_PUBLIC_KEYS variable is empty. Skipping adding keys."
    else
        echo "\$(date): --- Adding SSH Public Keys ---"
        
        # Add keys for root user
        echo "\$(date): Adding SSH keys for the 'root' user..."
        add_ssh_keys_for_user "root" "/root" "\$SSH_PUBLIC_KEYS"

        # Add keys for the new user if created
        if [ "\$CREATE_NEW_USER" = "true" ] && [ -n "\$NEW_SSH_USERNAME" ]; then
            echo "\$(date): Adding SSH keys for the new user '\$NEW_SSH_USERNAME'..."
            add_ssh_keys_for_user "\$NEW_SSH_USERNAME" "/home/\$NEW_SSH_USERNAME" "\$SSH_PUBLIC_KEYS"
        else
            echo "\$(date): Skipping SSH key addition for new user as CREATE_NEW_USER is 'false' or NEW_SSH_USERNAME is empty."
        fi

        echo "\$(date): All specified SSH Public Key configurations completed."
    fi
else
    echo "\$(date): Skipping SSH Public Key configuration as ADD_SSH_KEYS is 'false'."
fi

# --- 4. Configure Timezone ---
if [ "\$SET_TIMEZONE" = "true" ]; then
    if [ -z "\$NEW_TIMEZONE" ]; then
        echo "\$(date): WARNING: SET_TIMEZONE is 'true' but NEW_TIMEZONE variable is empty. Skipping timezone configuration."
    else
        echo "\$(date): --- Configuring Timezone ---"
        echo "\$(date): Setting system timezone to: \$NEW_TIMEZONE"
        timedatectl set-timezone "\$NEW_TIMEZONE" || echo "\$(date): WARNING: Failed to set timezone. Check if timezone is valid or 'timedatectl' command."
        echo "\$(date): Timezone configuration completed."
    fi
else
    echo "\$(date): Skipping timezone configuration as SET_TIMEZONE is 'false'."
fi

# --- Network IP Configuration (Conditionally executed) ---
if [ "\$CONFIGURE_NETWORK" = "true" ]; then
    echo "\$(date): --- Applying Network IP Configuration ---"
    echo "\$(date): Checking network interfaces..."

    # Get the UUID of the current management interface with retries
    echo "\$(date): Identifying the current management PIF with retries..."
    MANAGEMENT_PIF_UUID=""
    MAX_PIF_ATTEMPTS=12 # Try up to 12 times, 10s sleep each = 2 minutes total
    CURRENT_PIF_ATTEMPT=0
    PIF_SLEEP_SECONDS=10 # Wait 10 seconds between attempts

    while [ -z "\$MANAGEMENT_PIF_UUID" ] && [ "\$CURRENT_PIF_ATTEMPT" -lt "\$MAX_PIF_ATTEMPTS" ]; do
        CURRENT_PIF_ATTEMPT=\$((CURRENT_PIF_ATTEMPT + 1))
        echo "\$(date): Attempt \$CURRENT_PIF_ATTEMPT of \$MAX_PIF_ATTEMPTS: Running 'xe pif-list management=true --minimal'..."
        # Execute xe pif-list and capture output, redirecting stderr to /dev/null to suppress temporary errors
        MANAGEMENT_PIF_UUID=\$(xe pif-list management=true --minimal 2>/dev/null || true) 
        
        if [ -z "\$MANAGEMENT_PIF_UUID" ]; then
            echo "\$(date): Management PIF not found yet. Waiting \$PIF_SLEEP_SECONDS seconds..."
            sleep "\$PIF_SLEEP_SECONDS"
        fi
    done

    if [ -z "\$MANAGEMENT_PIF_UUID" ]; then
        error_exit "Could not find an active management interface (PIF) after \$MAX_PIF_ATTEMPTS attempts and \$((MAX_PIF_ATTEMPTS * PIF_SLEEP_SECONDS)) seconds for network configuration. Check 'xe pif-list'."
    fi
    echo "\$(date): Current management interface (PIF UUID): \$MANAGEMENT_PIF_UUID"

    echo "\$(date): Applying new configurations:"
    echo "  IP:           \$IP"
    echo "  Netmask:      \$NETMASK"
    echo "  Gateway:      \$GATEWAY"
    echo "  DNS(s):       \$DNS_SERVERS"
    echo ""

    echo "\$(date): Initiating network interface reconfiguration. Connectivity will be lost..."

    # Reconfigure the PIF IP
    xe pif-reconfigure-ip uuid="\$MANAGEMENT_PIF_UUID" mode=static IP="\$IP" netmask="\$NETMASK" gateway="\$GATEWAY" || \
        error_exit "Failed to reconfigure PIF IP. Check inputs and current network state."

    echo "\$(date): PIF IP reconfigured. Applying DNS configurations for the host..."

    # Configure the DNS servers for the host
    xe host-param-set uuid="\$HOST_UUID" other-config:external_dns="\$DNS_SERVERS" || \
        echo "\$(date): WARNING: Failed to configure host DNS servers. Please check manually." # Not a critical error for network itself

    echo "\$(date): Scanning for PIFs to ensure changes are registered..."
    xe pif-scan host-uuid="\$HOST_UUID" || \
        echo "\$(date): WARNING: pif-scan command failed. Manual intervention might be required."

    echo ""
    echo "\$(date): Network reconfiguration initiated. XCP-ng host should re-establish connectivity on the new IP: \$IP"
    echo "\$(date): Final verification of management PIF configurations (may fail if connection drops):"
    # This xe command might fail if SSH connection drops immediately. That's expected.
    xe pif-param-list uuid="\$MANAGEMENT_PIF_UUID" | grep -E 'device|IP|netmask|gateway|management' || \
        echo "\$(date): Could not fully verify PIF configuration via SSH (connection may have dropped)."
else
    echo "\$(date): Skipping network configuration as CONFIGURE_NETWORK is 'false'."
fi

echo ""
echo "\$(date): XCP-ng host initial setup script completed. Attempt to access the host on the configured IP address/hostname."

exit 0
EOF_XCP_SETUP
)


# Content of the Cloud-Init boot script to be deployed on the nested XCP-ng VM
# Note: Variables like $VM_NEW_IP are expanded by the *local* shell before transfer.
# Variables like \$LOG_FILE or \$(date) are escaped to be expanded by the *remote* shell.
read -r -d '' CLOUD_INIT_VM_SCRIPT_CONTENT << EOF
#!/bin/bash

# ===================================================================================
# Cloud-Init Boot Configuration Script for Nested XCP-ng VM
#
# Execution Context:
# This script is designed to run *only once* during the
# first boot of a **nested XCP-ng VM**. It acts as the "user-data"
# delivered via **Cloud-Init** by **Xen Orchestra** (if a user-data disk is present)
# or provides default network configuration if no user-data disk is found.
# ===================================================================================

# --- Configuration ---
LOG_FILE="/var/log/cloud-init-boot.log" # Log file for this script
MOUNT_POINT="/tmp/sdb_cloudinit_mount"  # Temporary mount point for the disk
SOURCE_DISK="/dev/sdb"                  # The disk containing the user-data script
USER_DATA_CONFIG_FILE="\${MOUNT_POINT}/user-data" # Path to the user-data (config) file on the mounted disk
MARKER_FILE="$REMOTE_MARKER_FILE"       # Marker file to ensure single execution
XCPNG_SETUP_SCRIPT="$REMOTE_XCPNG_SETUP_SCRIPT_PATH" # Path to the main XCP-ng setup script

# --- Functions ---
log_message() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" | tee -a "\$LOG_FILE"
}

error_exit() {
    log_message "ERROR: \$1"
    exit 1
}

# --- Script Start Logic ---
touch "\$LOG_FILE" || error_exit "Failed to create log file: \$LOG_FILE"
log_message "Starting Cloud-Init Boot script for nested XCP-ng VM."

if [ -f "\$MARKER_FILE" ]; then
    log_message "Marker file '\$MARKER_FILE' found. This is not the first boot (Cloud-Init already executed). Exiting."
    exit 0
fi

log_message "No marker file found. Proceeding with Cloud-Init Boot tasks."

# --- Wait for XAPI to be active ---
log_message "Waiting for XAPI service to be active..."
MAX_ATTEMPTS_XAPI=60 # Max 60 attempts (10 minutes)
ATTEMPT_XAPI=0
while ! systemctl is-active --quiet xapi; do
    if [ \$ATTEMPT_XAPI -ge \$MAX_ATTEMPTS_XAPI ]; then
        error_exit "XAPI service did not become active after \$MAX_ATTEMPTS_XAPI attempts. Cannot proceed."
    fi
    log_message "XAPI is not yet active. Waiting 10 seconds... (Attempt \$((ATTEMPT_XAPI + 1))/\$MAX_ATTEMPTS_XAPI)"
    sleep 10
    ATTEMPT_XAPI=\$((ATTEMPT_XAPI + 1))
done
log_message "XAPI service is now active."

# --- Check for the existence of /dev/sdb (Cloud-Init User-Data Disk) ---
if [ ! -b "\$SOURCE_DISK" ]; then
    log_message "Source disk '\$SOURCE_DISK' does not exist or is not a block device."
    log_message "Assuming no Cloud-Init user-data disk is present. Proceeding with default network configuration (DHCP)."

    # --- Start XCP-ng Management PIF DHCP Configuration ---
    # This block is executed ONLY if SOURCE_DISK does not exist.
    log_message "--- Starting XCP-ng Management PIF DHCP Configuration (No Cloud-Init Disk) ---"

    # 1. Get the UUID of the current management PIF with a retry loop
    log_message "Identifying the current management PIF with retries..."
    MANAGEMENT_PIF_UUID=""
    MAX_PIF_ATTEMPTS=12 # Try up to 12 times, 10s sleep each = 2 minutes total
    CURRENT_PIF_ATTEMPT=0
    PIF_SLEEP_SECONDS=10 # Wait 10 seconds between attempts

    while [ -z "\$MANAGEMENT_PIF_UUID" ] && [ "\$CURRENT_PIF_ATTEMPT" -lt "\$MAX_PIF_ATTEMPTS" ]; do
        CURRENT_PIF_ATTEMPT=\$((CURRENT_PIF_ATTEMPT + 1))
        log_message "Attempt \$CURRENT_PIF_ATTEMPT of \$MAX_PIF_ATTEMPTS: Running 'xe pif-list management=true --minimal'..."
        # Execute xe pif-list and capture output, redirecting stderr to /dev/null to suppress temporary errors
        MANAGEMENT_PIF_UUID=\$(xe pif-list management=true --minimal 2>/dev/null || true) 
        
        if [ -z "\$MANAGEMENT_PIF_UUID" ]; then
            log_message "Management PIF not found yet. Waiting \$PIF_SLEEP_SECONDS seconds..."
            sleep "\$PIF_SLEEP_SECONDS"
        fi
    done

    if [ -z "\$MANAGEMENT_PIF_UUID" ]; then
        error_exit "Could not find a management PIF on this host after \$MAX_PIF_ATTEMPTS attempts and \$((MAX_PIF_ATTEMPTS * PIF_SLEEP_SECONDS)) seconds. Cannot configure DHCP."
    fi

    log_message "Management PIF UUID found: \$MANAGEMENT_PIF_UUID"

    # 2. Get details about the management PIF before changing (optional, for logging)
    log_message "Current management PIF details:"
    xe pif-param-list uuid="\$MANAGEMENT_PIF_UUID" | grep -E 'device|IP|netmask|mode' || log_message "Could not retrieve full PIF details."

    # 3. Reconfigure the management PIF to DHCP mode
    log_message "Configuring management PIF '\$MANAGEMENT_PIF_UUID' to DHCP mode..."
    xe pif-reconfigure-ip uuid="\$MANAGEMENT_PIF_UUID" mode=DHCP || error_exit "Failed to configure PIF to DHCP."

    log_message "--- XCP-ng Management PIF DHCP Configuration Completed. ---"
    log_message "The management interface of this XCP-ng host has been set to DHCP mode."
    log_message "The host will now attempt to obtain an IP address via DHCP."
    log_message "There might be a brief interruption in connectivity while the new IP is acquired."

    # Create marker file and exit if no user-data disk was present.
    # The script completes here as there's no user-data to process.
    log_message "Creating marker file '\$MARKER_FILE' to prevent future executions (DHCP configured, no user-data processed)."
    touch "\$MARKER_FILE" || log_message "WARNING: Failed to create marker file. Script might run again on next boot."
    log_message "Cloud-Init Boot script finished (DHCP configured, no user-data)."
    exit 0 # Exit here, as no user-data disk implies our task is done.

else
    # --- Source Disk exists: Proceed with Cloud-Init user-data processing ---
    log_message "Source disk '\$SOURCE_DISK' found. Proceeding with user-data processing."

    log_message "Creating mount point: \$MOUNT_POINT"
    mkdir -p "\$MOUNT_POINT" || error_exit "Failed to create mount point: \$MOUNT_POINT"

    log_message "Mounting \$SOURCE_DISK on \$MOUNT_POINT..."
    # Add retry logic for mounting
    MAX_MOUNT_ATTEMPTS=5
    CURRENT_MOUNT_ATTEMPT=0
    MOUNT_SLEEP_SECONDS=5

    while ! mount "\$SOURCE_DISK" "\$MOUNT_POINT"; do
        CURRENT_MOUNT_ATTEMPT=\$((CURRENT_MOUNT_ATTEMPT + 1))
        if [ \$CURRENT_MOUNT_ATTEMPT -ge \$MAX_MOUNT_ATTEMPTS ]; then
            error_exit "Failed to mount \$SOURCE_DISK after \$MAX_MOUNT_ATTEMPTS attempts. Exiting."
        fi
        log_message "Failed to mount \$SOURCE_DISK. Retrying in \$MOUNT_SLEEP_SECONDS seconds... (Attempt \$CURRENT_MOUNT_ATTEMPT/\$MAX_MOUNT_ATTEMPTS)"
        sleep "\$MOUNT_SLEEP_SECONDS"
    done
    log_message "\$SOURCE_DISK mounted successfully."

    # Ensure the user-data file exists before trying to execute the setup script with it
    if [ -f "\$USER_DATA_CONFIG_FILE" ]; then
        log_message "User-data config file found: \$USER_DATA_CONFIG_FILE"
        log_message "Executing XCP-ng setup script: \$XCPNG_SETUP_SCRIPT with config from \$USER_DATA_CONFIG_FILE"
        # Execute the main XCP-ng setup script, passing the user-data file as its configuration source
        /bin/bash "\$XCPNG_SETUP_SCRIPT" "\$USER_DATA_CONFIG_FILE" >> "\$LOG_FILE" 2>&1
        XCPNG_SETUP_EXIT_CODE=\$?
        if [ \$XCPNG_SETUP_EXIT_CODE -eq 0 ]; then
            log_message "XCP-ng setup script executed successfully."
        else
            log_message "XCP-ng setup script exited with code \$XCPNG_SETUP_EXIT_CODE. Check \$LOG_FILE for details."
        fi
    else
        log_message "User-data configuration file not found at \$USER_DATA_CONFIG_FILE. Skipping XCP-ng setup script execution."
    fi

    log_message "Unmounting \$MOUNT_POINT..."
    if ! umount "\$MOUNT_POINT"; then
        log_message "Failed to unmount \$MOUNT_POINT. Manual unmount might be required. Proceeding anyway."
    fi
    log_message "\$MOUNT_POINT unmounted successfully."

    log_message "Removing mount point directory: \$MOUNT_POINT"
    rmdir "\$MOUNT_POINT" || log_message "Failed to remove mount point directory. It might not be empty."

fi # End of if/else for SOURCE_DISK existence

log_message "Creating marker file '\$MARKER_FILE' to prevent future executions."
touch "\$MARKER_FILE" || log_message "WARNING: Failed to create marker file. Script might run again on next boot."

log_message "Cloud-Init Boot script finished."

exit 0
EOF

# Content of the systemd service file to be deployed on the nested XCP-ng VM
read -r -d '' SYSTEMD_SERVICE_CONTENT << EOF
[Unit]
Description=XCP-ng Cloud-Init Boot Configuration
# Ensure network is up before running
After=network-online.target remote-fs.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH
RemainAfterExit=true
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

# --- Remote Execution on XCP-ng Host ---

echo "--- Starting remote configuration on XCP-ng host ($XCPNG_HOST) ---"

# 1. Create /usr/local/bin directory if it doesn't exist
execute_remote "mkdir -p /usr/local/bin"

# 2. Create the main XCP-ng setup script on the remote host
echo "Creating the XCP-ng setup script at $REMOTE_XCPNG_SETUP_SCRIPT_PATH..."
execute_remote "sudo tee $REMOTE_XCPNG_SETUP_SCRIPT_PATH > /dev/null" "$XCP_NG_SETUP_SCRIPT_MODIFIED_CONTENT"

# 3. Give execute permission to the XCP-ng setup script
echo "Setting execute permissions for the XCP-ng setup script: $REMOTE_XCPNG_SETUP_SCRIPT_PATH"
execute_remote "chmod +x $REMOTE_XCPNG_SETUP_SCRIPT_PATH"

# 4. Create the Cloud-Init Boot script on the remote host
echo "Creating the Cloud-Init Boot script at $REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH..."
execute_remote "sudo tee $REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH > /dev/null" "$CLOUD_INIT_VM_SCRIPT_CONTENT"

# 5. Give execute permission to the Cloud-Init Boot script
echo "Setting execute permissions for the Cloud-Init Boot script: $REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH"
execute_remote "chmod +x $REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH"

# 6. Create the systemd service file on the remote host
echo "Creating the systemd service file at $REMOTE_SERVICE_PATH..."
execute_remote "sudo tee $REMOTE_SERVICE_PATH > /dev/null" "$SYSTEMD_SERVICE_CONTENT"

# 7. Reload systemd manager configuration
echo "Reloading systemd manager configuration..."
execute_remote "systemctl daemon-reload"

# 8. Enable the service to start on boot
echo "Enabling the service 'cloud-init-boot.service' to start on boot..."
execute_remote "systemctl enable cloud-init-boot.service"

echo "--- Remote configuration completed. ---"
echo "The scripts '$REMOTE_XCPNG_SETUP_SCRIPT_PATH' and '$REMOTE_CLOUD_INIT_BOOT_SCRIPT_PATH',"
echo "and the systemd service 'cloud-init-boot.service' have been configured on host '$XCPNG_HOST'."
echo "For changes to take effect, you must **reboot the XCP-ng host (nested VM)**."

exit 0