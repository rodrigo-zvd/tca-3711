#!/bin/bash

# Script to configure an XCP-ng host, including network settings, hostname,
# user management, SSH keys, and timezone.
# This script is designed for automated (non-interactive) execution via Terraform's remote-exec SSH provisioner.

# Set -e ensures that the script exits immediately if any command fails.
set -e

# --- Initial Diagnostic Output ---
echo "$(date): Script started. Performing initial environment checks."
# Ensure stderr is also captured by Terraform for early errors
exec 2>&1

# --- Configuration Variables (ADJUST THESE VALUES!) ---
# ENSURE THESE VALUES ARE CORRECT FOR YOUR ENVIRONMENT AND SECURITY POLICIES.
# Terraform users: These variables should ideally be passed in via templatefile
# or directly interpolated from Terraform variables, not hardcoded here.

# --- Network Configuration Flag ---
CONFIGURE_NETWORK="true"       # Set to "true" to apply network settings, "false" to skip.

# --- Network Settings (Only applied if CONFIGURE_NETWORK is "true") ---
# Example values; REPLACE WITH YOUR ACTUAL NETWORK SETTINGS
IP="192.168.1.70"                 # New IP address for the XCP-ng host
NETMASK="255.255.255.0"         # New subnet mask
GATEWAY="192.168.1.1"           # New default gateway
DNS_SERVERS="192.168.1.2,8.8.8.8"   # New DNS servers (comma-separated, e.g., "8.8.8.8,8.8.4.4")

# --- Hostname Configuration ---
SET_HOSTNAME="${SET_HOSTNAME_PLACEHOLDER}"            # Set to "true" to change hostname, "false" to skip
NEW_HOSTNAME="${HOSTNAME_PLACEHOLDER}" # Desired new hostname

# --- User and Password Management ---
# You can set both CREATE_NEW_USER and ROOT_PASSWORD_CHANGE to "true" simultaneously.

CREATE_NEW_USER="true"         # Set to "true" to create a new user, "false" to skip
NEW_SSH_USERNAME="xcpadmin"    # Username for the new SSH user
NEW_USER_PASSWORD="NewStrongPassword123!" # Password for the new SSH user (MAKE THIS VERY STRONG AND UNIQUE!)
ADD_USER_TO_SUDO_GROUP="true"  # Set to "true" to add the new user to the 'wheel' group (for sudo)

ROOT_PASSWORD_CHANGE="true"    # Set to "true" to change root password directly, "false" to skip
NEW_ROOT_PASSWORD="123456" # New password for the root user (MAKE THIS VERY STRONG AND UNIQUE!)

# --- SSH Public Key Configuration ---
ADD_SSH_KEYS="true"            # Set to "true" to add SSH public keys, "false" to skip
# Provide one or more public keys, each on a new line within the heredoc.
# Ensure correct formatting (e.g., "ssh-rsa AAAAB3NzaC... user@example.com")
# Use 'EOF' without quotes (as done here) to prevent shell variable expansion in the keys themselves.
read -r SSH_PUBLIC_KEYS << 'EOF'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAN3JnFSajM3rl8Dg6Pj/ffFpE4dYK9dEiftI2Y2Cke0 rodrigo@YogaSlim6
EOF

# --- Timezone Configuration ---
SET_TIMEZONE="true"            # Set to "true" to change timezone, "false" to skip
NEW_TIMEZONE="America/Manaus" # Example: "America/New_York", "Europe/London", "Asia/Tokyo"
                                 # Find valid timezones with 'timedatectl list-timezones'

# --- HELPER FUNCTIONS ---

# Function to display an error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# Function to validate basic IP format
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
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
# Args: $1=username, $2=home_directory, $3=public_keys_content
add_ssh_keys_for_user() {
    local user_name="$1"
    local home_dir="$2"
    local public_keys="$3"

    if [ -z "$public_keys" ]; then
        echo "$(date): WARNING: No public keys provided for user '$user_name'. Skipping key addition."
        return 0
    fi

    echo "$(date): Adding SSH keys for user '$user_name' in '$home_dir/.ssh'..."
    local ssh_dir="${home_dir}/.ssh"
    local authorized_keys_file="${ssh_dir}/authorized_keys"

    mkdir -p "$ssh_dir" || error_exit "Failed to create SSH directory for '$user_name'."
    chmod 700 "$ssh_dir" || error_exit "Failed to set permissions on SSH directory '$ssh_dir'."

    # Set ownership for the .ssh directory immediately
    # This is important if creating for a non-root user
    if [ "$user_name" != "root" ]; then
        chown "$user_name":"$user_name" "$ssh_dir" || echo "$(date): WARNING: Failed to set ownership for '$ssh_dir' for user '$user_name'."
    fi

    # Append keys, making sure to avoid duplicates if re-running script
    # Each key is processed on a new line
    echo "$public_keys" | while IFS= read -r key_line; do
        # Skip empty lines and comments
        [[ -z "$key_line" || "${key_line:0:1}" == "#" ]] && continue
        if ! grep -qF "$key_line" "$authorized_keys_file" 2>/dev/null; then
            echo "$key_line" >> "$authorized_keys_file"
            echo "$(date): Added key for '$user_name': ${key_line%% *}" # Print only the key type and part of the key for brevity
        else
            echo "$(date): Key already exists for '$user_name', skipping: ${key_line%% *}"
        fi
    done

    chmod 600 "$authorized_keys_file" || error_exit "Failed to set permissions on '$authorized_keys_file'."

    # Set ownership for authorized_keys file
    if [ "$user_name" != "root" ]; then
        chown "$user_name":"$user_name" "$authorized_keys_file" || echo "$(date): WARNING: Failed to set ownership for '$authorized_keys_file' for user '$user_name'."
    fi

    echo "$(date): SSH Public Key configuration completed for user '$user_name'."
}


# --- SCRIPT START ---

echo "$(date): --- AUTOMATED XCP-ng HOST INITIAL CONFIGURATION ---"
echo ""
echo "CRITICAL WARNINGS:"
if [ "$CONFIGURE_NETWORK" = "true" ]; then
    echo "1. This script will change the IP address of the XCP-ng host's management interface."
    echo "   SSH/console connectivity to this host may be LOST and re-established on the new IP."
fi
echo "2. It may modify user accounts/passwords and add SSH keys based on configuration."
echo "3. Ensure that ALL Configuration Variables are correct for your environment."
echo "4. It is HIGHLY recommended to have local console access (IPMI/iLO/DRAC) in case of failure."
echo ""

# Validate the defined IPs only if network configuration is enabled
if [ "$CONFIGURE_NETWORK" = "true" ]; then
    echo "$(date): Validating network IP and Gateway..."
    validate_ip "$IP" || error_exit "The IP '$IP' defined in IP variable is invalid."
    validate_ip "$GATEWAY" || error_exit "The Gateway '$GATEWAY' defined in GATEWAY variable is invalid."
    echo "$(date): Network IP and Gateway validation successful."
fi

echo "$(date): Checking host UUID..."

# Get the Host UUID
# Added `|| true` to prevent `set -e` from exiting if xe host-list temporarily fails or gives no output (though it should exist)
HOST_UUID=$(xe host-list --minimal 2>/dev/null || true)
if [ -z "$HOST_UUID" ]; then
    # Add a retry loop for host-list as well, as XAPI might still be coming up
    echo "$(date): Host UUID not found immediately. Retrying..."
    MAX_HOST_UUID_ATTEMPTS=6
    CURRENT_HOST_UUID_ATTEMPT=0
    HOST_UUID_SLEEP_SECONDS=5

    while [ -z "$HOST_UUID" ] && [ "$CURRENT_HOST_UUID_ATTEMPT" -lt "$MAX_HOST_UUID_ATTEMPTS" ]; do
        CURRENT_HOST_UUID_ATTEMPT=$((CURRENT_HOST_UUID_ATTEMPT + 1))
        echo "$(date): Attempt $CURRENT_HOST_UUID_ATTEMPT of $MAX_HOST_UUID_ATTEMPTS: Running 'xe host-list --minimal'..."
        HOST_UUID=$(xe host-list --minimal 2>/dev/null || true)
        if [ -z "$HOST_UUID" ]; then
            echo "$(date): Host UUID not found yet. Waiting $HOST_UUID_SLEEP_SECONDS seconds..."
            sleep "$HOST_UUID_SLEEP_SECONDS"
        fi
    done

    if [ -z "$HOST_UUID" ]; then
        error_exit "Could not get the host UUID after $MAX_HOST_UUID_ATTEMPTS attempts. XCP-ng host might not be fully ready or 'xe' command is unavailable."
    fi
fi
echo "$(date): Host UUID: $HOST_UUID"

# --- 1. Configure Hostname ---
if [ "$SET_HOSTNAME" = "true" ]; then
    echo "$(date): --- Configuring Hostname ---"
    echo "$(date): Setting host name-label via xe to: $NEW_HOSTNAME"
    xe host-set-hostname-live host-uuid="$HOST_UUID" host-name="$NEW_HOSTNAME" || echo "$(date): WARNING: Failed to set host name-label via xe. Please check manually."
    # The 'hostnamectl set-hostname' command is typically not necessary on XCP-ng as 'xe host-set-hostname-live' handles the XenServer specific hostname.
    # echo "$(date): Setting system hostname with hostnamectl to: $NEW_HOSTNAME"
    # hostnamectl set-hostname "$NEW_HOSTNAME" || echo "$(date): WARNING: Failed to set system hostname with hostnamectl. Check logs."
    echo "$(date): Hostname configuration completed."
else
    echo "$(date): Skipping hostname configuration as SET_HOSTNAME is 'false'."
fi

# --- 2. User and Password Management ---
echo "$(date): --- User and Password Management ---"
if [ "$CREATE_NEW_USER" = "true" ]; then
    if [ -z "$NEW_SSH_USERNAME" ] || [ -z "$NEW_USER_PASSWORD" ]; then
        error_exit "NEW_SSH_USERNAME or NEW_USER_PASSWORD is empty when CREATE_NEW_USER is true. Aborting user creation."
    fi

    echo "$(date): Attempting to create or verify user '$NEW_SSH_USERNAME'..."
    if id "$NEW_SSH_USERNAME" &>/dev/null; then
        echo "$(date): User '$NEW_SSH_USERNAME' already exists. Updating password."
    else
        useradd -m -s /bin/bash "$NEW_SSH_USERNAME" || error_exit "Failed to create user '$NEW_SSH_USERNAME'."
        echo "$(date): User '$NEW_SSH_USERNAME' created."
    fi

    echo "${NEW_SSH_USERNAME}:${NEW_USER_PASSWORD}" | chpasswd || error_exit "Failed to set password for user '$NEW_SSH_USERNAME'. Ensure password meets requirements."
    echo "$(date): Password set for user '$NEW_SSH_USERNAME'."

    if [ "$ADD_USER_TO_SUDO_GROUP" = "true" ]; then
        echo "$(date): Adding user '$NEW_SSH_USERNAME' to 'wheel' group for sudo access..."
        usermod -aG wheel "$NEW_SSH_USERNAME" || echo "$(date): WARNING: Failed to add user '$NEW_SSH_USERNAME' to 'wheel' group. Manual verification needed for sudo."
        echo "$(date): User '$NEW_SSH_USERNAME' added to 'wheel' group."
    fi
else
    echo "$(date): Skipping new user creation as CREATE_NEW_USER is 'false'."
fi

if [ "$ROOT_PASSWORD_CHANGE" = "true" ]; then
    if [ -z "$NEW_ROOT_PASSWORD" ]; then
        error_exit "NEW_ROOT_PASSWORD is empty when ROOT_PASSWORD_CHANGE is true. Aborting root password change."
    fi
    echo "$(date): Changing root password..."
    echo "root:${NEW_ROOT_PASSWORD}" | chpasswd || error_exit "Failed to change root password. Ensure password meets requirements."
    echo "$(date): Root password changed."
else
    echo "$(date): Skipping root password change as ROOT_PASSWORD_CHANGE is 'false'."
fi

# --- 3. Add SSH Public Keys ---
if [ "$ADD_SSH_KEYS" = "true" ]; then
    if [ -z "$SSH_PUBLIC_KEYS" ]; then
        echo "$(date): WARNING: ADD_SSH_KEYS is 'true' but SSH_PUBLIC_KEYS variable is empty. Skipping adding keys."
    else
        echo "$(date): --- Adding SSH Public Keys ---"
        
        # Add keys for root user
        echo "$(date): Adding SSH keys for the 'root' user..."
        add_ssh_keys_for_user "root" "/root" "$SSH_PUBLIC_KEYS"

        # Add keys for the new user if created
        if [ "$CREATE_NEW_USER" = "true" ] && [ -n "$NEW_SSH_USERNAME" ]; then
            echo "$(date): Adding SSH keys for the new user '$NEW_SSH_USERNAME'..."
            add_ssh_keys_for_user "$NEW_SSH_USERNAME" "/home/$NEW_SSH_USERNAME" "$SSH_PUBLIC_KEYS"
        else
            echo "$(date): Skipping SSH key addition for new user as CREATE_NEW_USER is 'false' or NEW_SSH_USERNAME is empty."
        fi

        echo "$(date): All specified SSH Public Key configurations completed."
    fi
else
    echo "$(date): Skipping SSH Public Key configuration as ADD_SSH_KEYS is 'false'."
fi

# --- 4. Configure Timezone ---
if [ "$SET_TIMEZONE" = "true" ]; then
    if [ -z "$NEW_TIMEZONE" ]; then
        echo "$(date): WARNING: SET_TIMEZONE is 'true' but NEW_TIMEZONE variable is empty. Skipping timezone configuration."
    else
        echo "$(date): --- Configuring Timezone ---"
        echo "$(date): Setting system timezone to: $NEW_TIMEZONE"
        timedatectl set-timezone "$NEW_TIMEZONE" || echo "$(date): WARNING: Failed to set timezone. Check if timezone is valid or 'timedatectl' command."
        echo "$(date): Timezone configuration completed."
    fi
else
    echo "$(date): Skipping timezone configuration as SET_TIMEZONE is 'false'."
fi


# --- Network IP Configuration (Conditionally executed) ---
if [ "$CONFIGURE_NETWORK" = "true" ]; then
    echo "$(date): --- Applying Network IP Configuration ---"
    echo "$(date): Checking network interfaces..."

    # Get the UUID of the current management interface with retries
    echo "$(date): Identifying the current management PIF with retries..."
    MANAGEMENT_PIF_UUID=""
    MAX_PIF_ATTEMPTS=12 # Try up to 12 times, 10s sleep each = 2 minutes total
    CURRENT_PIF_ATTEMPT=0
    PIF_SLEEP_SECONDS=10 # Wait 10 seconds between attempts

    while [ -z "$MANAGEMENT_PIF_UUID" ] && [ "$CURRENT_PIF_ATTEMPT" -lt "$MAX_PIF_ATTEMPTS" ]; do
        CURRENT_PIF_ATTEMPT=$((CURRENT_PIF_ATTEMPT + 1))
        echo "$(date): Attempt $CURRENT_PIF_ATTEMPT of $MAX_PIF_ATTEMPTS: Running 'xe pif-list management=true --minimal'..."
        # Execute xe pif-list and capture output, redirecting stderr to /dev/null to suppress temporary errors
        MANAGEMENT_PIF_UUID=$(xe pif-list management=true --minimal 2>/dev/null || true) 
        
        if [ -z "$MANAGEMENT_PIF_UUID" ]; then
            echo "$(date): Management PIF not found yet. Waiting $PIF_SLEEP_SECONDS seconds..."
            sleep "$PIF_SLEEP_SECONDS"
        fi
    done

    if [ -z "$MANAGEMENT_PIF_UUID" ]; then
        error_exit "Could not find an active management interface (PIF) after $MAX_PIF_ATTEMPTS attempts and $((MAX_PIF_ATTEMPTS * PIF_SLEEP_SECONDS)) seconds for network configuration. Check 'xe pif-list'."
    fi
    echo "$(date): Current management interface (PIF UUID): $MANAGEMENT_PIF_UUID"

    echo "$(date): Applying new configurations:"
    echo "  IP:           $IP"
    echo "  Netmask:      $NETMASK"
    echo "  Gateway:      $GATEWAY"
    echo "  DNS(s):       $DNS_SERVERS"
    echo ""

    echo "$(date): Initiating network interface reconfiguration. Connectivity will be lost..."

    # Reconfigure the PIF IP
    xe pif-reconfigure-ip uuid="$MANAGEMENT_PIF_UUID" mode=static IP="$IP" netmask="$NETMASK" gateway="$GATEWAY" || \
        error_exit "Failed to reconfigure PIF IP. Check inputs and current network state."

    echo "$(date): PIF IP reconfigured. Applying DNS configurations for the host..."

    # Configure the DNS servers for the host
    xe host-param-set uuid="$HOST_UUID" other-config:external_dns="$DNS_SERVERS" || \
        echo "$(date): WARNING: Failed to configure host DNS servers. Please check manually." # Not a critical error for network itself

    echo "$(date): Scanning for PIFs to ensure changes are registered..."
    xe pif-scan host-uuid="$HOST_UUID" || \
        echo "$(date): WARNING: pif-scan command failed. Manual intervention might be required."

    echo ""
    echo "$(date): Network reconfiguration initiated. XCP-ng host should re-establish connectivity on the new IP: $IP"
    echo "$(date): Final verification of management PIF configurations (may fail if connection drops):"
    # This xe command might fail if SSH connection drops immediately. That's expected.
    xe pif-param-list uuid="$MANAGEMENT_PIF_UUID" | grep -E 'device|IP|netmask|gateway|management' || \
        echo "$(date): Could not fully verify PIF configuration via SSH (connection may have dropped)."
else
    echo "$(date): Skipping network configuration as CONFIGURE_NETWORK is 'false'."
fi

echo ""
echo "$(date): XCP-ng host initial setup script completed. Attempt to access the host on the configured IP address/hostname."

exit 0