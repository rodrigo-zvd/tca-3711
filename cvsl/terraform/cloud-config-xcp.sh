#!/bin/bash

# Configuration Variables for XCP-ng Host Initial Setup
# ENSURE THESE VALUES ARE CORRECT FOR YOUR ENVIRONMENT AND SECURITY POLICIES.
# Terraform users: These variables should ideally be passed in via templatefile
# or directly interpolated from Terraform variables, not hardcoded here.

# --- Network Configuration Flag ---
CONFIGURE_NETWORK="${CONFIGURE_NETWORK_PLACEHOLDER}"       # Set to "true" to apply network settings, "false" to skip.

# --- Network Settings (Only applied if CONFIGURE_NETWORK is "true") ---
# Example values; REPLACE WITH YOUR ACTUAL NETWORK SETTINGS
IP="${IP_PLACEHOLDER}"                 # New IP address for the XCP-ng host
NETMASK="${NETMASK_PLACEHOLDER}"         # New subnet mask
GATEWAY="${GATEWAY_PLACEHOLDER}"           # New default gateway
DNS_SERVERS="${DNS_SERVERS_PLACEHOLDER}"   # New DNS servers (comma-separated, e.g., "8.8.8.8,8.8.4.4")

# --- Hostname Configuration ---
SET_HOSTNAME="${SET_HOSTNAME_PLACEHOLDER}"            # Set to "true" to change hostname, "false" to skip
NEW_HOSTNAME="${HOSTNAME_PLACEHOLDER}" # Desired new hostname

# --- User and Password Management ---
# You can set both CREATE_NEW_USER and ROOT_PASSWORD_CHANGE to "true" simultaneously.

CREATE_NEW_USER="${CREATE_NEW_USER_PLACEHOLDER}"         # Set to "true" to create a new user, "false" to skip
NEW_SSH_USERNAME="${NEW_SSH_USER_PLACEHOLDER}"    # Username for the new SSH user
NEW_USER_PASSWORD="${NEW_USER_PASSWORD_PLACEHOLDER}" # Password for the new SSH user (MAKE THIS VERY STRONG AND UNIQUE!)
ADD_USER_TO_SUDO_GROUP="${ADD_USER_TO_SUDO_GROUP_PLACEHOLDER}"  # Set to "true" to add the new user to the 'wheel' group (for sudo)

ROOT_PASSWORD_CHANGE="${ROOT_PASSWORD_CHANGE_PLACEHOLDER}"    # Set to "true" to change root password directly, "false" to skip
NEW_ROOT_PASSWORD="${NEW_ROOT_PASSWORD_PLACEHOLDER}" # New password for the root user (MAKE THIS VERY STRONG AND UNIQUE!)

# --- SSH Public Key Configuration ---
ADD_SSH_KEYS="${ADD_SSH_KEYS_PLACEHOLDER}"            # Set to "true" to add SSH public keys, "false" to skip
# Provide one or more public keys, each on a new line within the heredoc.
# Ensure correct formatting (e.g., "ssh-rsa AAAAB3NzaC... user@example.com")
# Use 'EOF' without quotes (as done here) to prevent shell variable expansion in the keys themselves.
read -r SSH_PUBLIC_KEYS << 'EOF'
${SSH_PUBLIC_KEYS_PLACEHOLDER}
EOF

# --- Timezone Configuration ---
SET_TIMEZONE="${SET_TIMEZONE_PLACEHOLDER}"            # Set to "true" to change timezone, "false" to skip
NEW_TIMEZONE="${NEW_TIMEZONE_PLACEHOLDER}" # Example: "America/New_York", "Europe/London", "Asia/Tokyo"
                                 # Find valid timezones with 'timedatectl list-timezones'