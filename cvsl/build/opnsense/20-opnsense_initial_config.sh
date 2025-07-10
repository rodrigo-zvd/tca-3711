#!/bin/sh

# === LOGGING CONFIGURATION ===
LOG_FILE="/var/log/opnsense-initial-config.log"

# Function to log messages, to console and file
log_message() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

log_message "Starting initial configuration script for OPNsense."

# === CONTROL VARIABLES ===
BOOT_FLAG_FILE="/conf/opnsense_initial_config_done"
USER_DATA_DEVICE="/dev/ada1s1" # User data partition (slice 1)
USER_DATA_MOUNT_POINT="/mnt/opnsense-user-data"
USER_DATA_FILE="user-data" # Name of the user-data file on the disk

# === FIRST BOOT CHECK ===
if [ -f "$BOOT_FLAG_FILE" ]; then
  log_message "Script already executed on a previous boot. Exiting."
  exit 0
fi

# === USER DATA DISK CHECK AND WAIT ===
MAX_RETRIES=10
RETRY_DELAY=3 # seconds
CURRENT_RETRY=0
DEVICE_READY=0

log_message "Checking for user-data partition existence and readiness ($USER_DATA_DEVICE)."
while [ "$CURRENT_RETRY" -lt "$MAX_RETRIES" ]; do
  # Checking for existence (-e) instead of block device (-b) as requested
  if [ -e "$USER_DATA_DEVICE" ]; then
    log_message "User-data partition $USER_DATA_DEVICE found after $CURRENT_RETRY retries."
    DEVICE_READY=1
    break
  else
    log_message "User-data partition $USER_DATA_DEVICE not found. Attempt $((CURRENT_RETRY + 1)) of $MAX_RETRIES. Waiting $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
    CURRENT_RETRY=$((CURRENT_RETRY + 1))
  fi
done

if [ "$DEVICE_READY" -eq 0 ]; then
  log_message "User-data partition $USER_DATA_DEVICE did not become available after multiple attempts. Exiting."
  exit 1
fi

# === MOUNT DISK AND PARSE YAML FILE ===
log_message "Attempting to mount $USER_DATA_DEVICE to read user-data."
mkdir -p "$USER_DATA_MOUNT_POINT"

# Attempt to mount with different file system types, prioritizing 'msdosfs' (FAT32)
MOUNT_SUCCESS=0
for fs_type in msdosfs cd9660 ufs; do
  log_message "Attempting to mount $USER_DATA_DEVICE as $fs_type..."
  if mount -t "$fs_type" "$USER_DATA_DEVICE" "$USER_DATA_MOUNT_POINT"; then
    log_message "Partition $USER_DATA_DEVICE mounted successfully as $fs_type."
    MOUNT_SUCCESS=1
    break
  fi
done

if [ "$MOUNT_SUCCESS" -eq 0 ]; then
  log_message "Failed to mount $USER_DATA_DEVICE. None of the file system attempts (msdosfs, cd9660, ufs) worked. Check partition format."
  rmdir "$USER_DATA_MOUNT_POINT"
  exit 1
fi

USER_DATA_PATH="$USER_DATA_MOUNT_POINT/$USER_DATA_FILE"

if [ ! -f "$USER_DATA_PATH" ]; then
  log_message "User-data file '$USER_DATA_FILE' not found at $USER_DATA_PATH. Unmounting and exiting."
  umount "$USER_DATA_MOUNT_POINT"
  rmdir "$USER_DATA_MOUNT_POINT"
  exit 1
fi

log_message "Reading parameters from YAML file: $USER_DATA_PATH"

# --- YAML PARSING WITH NATIVE COMMANDS ---
# Helper function to extract simple YAML values, with robust whitespace trimming.
get_yaml_value() {
  local key="$1"
  local file="$2"
  # Search for the line containing the key, remove leading/trailing whitespace from the line,
  # extract the value after ': ', remove quotes (if present) and '\r' (CR).
  grep "^  $key:" "$file" | sed -E "s/^  $key:[[:space:]]*(.*)[[:space:]]*$/\1/" | sed -E "s/^\"(.*)\"$/\1/" | tr -d '\r'
}

TEMPLATE_XML=$(get_yaml_value "TEMPLATE_XML" "$USER_DATA_PATH")
TARGET_XML=$(get_yaml_value "TARGET_XML" "$USER_DATA_PATH")
WAN_IF=$(get_yaml_value "WAN_IF" "$USER_DATA_PATH")
IP=$(get_yaml_value "IP" "$USER_DATA_PATH")
SUBNET=$(get_yaml_value "SUBNET" "$USER_DATA_PATH")
GATEWAY=$(get_yaml_value "GATEWAY" "$USER_DATA_PATH")
DNS=$(get_yaml_value "DNS" "$USER_DATA_PATH")

# Unmount the disk
log_message "Unmounting $USER_DATA_MOUNT_POINT."
umount "$USER_DATA_MOUNT_POINT"
rmdir "$USER_DATA_MOUNT_POINT"

# === VARIABLE VALIDATION ===
if [ -z "$TEMPLATE_XML" ] || [ -z "$TARGET_XML" ] || [ -z "$IP" ] || [ -z "$SUBNET" ] || [ -z "$GATEWAY" ] || [ -z "$DNS" ]; then
  log_message "Error: One or more essential variables could not be loaded from user-data. Check YAML file and its formatting."
  exit 1
fi

log_message "Variables loaded: IP=$IP, GATEWAY=$GATEWAY, DNS=$DNS, TEMPLATE_XML=$TEMPLATE_XML"

# === CHECK TEMPLATE EXISTS ===
if [ ! -f "$TEMPLATE_XML" ]; then
  log_message "[!] Template file not found: '$TEMPLATE_XML'. Verify the path in user-data is exact."
  exit 1
fi

# === BACKUP ACTIVE CONFIG BEFORE OVERWRITE ===
cp "$TARGET_XML" "${TARGET_XML}.bak"
log_message "[*] Backup of current config created at ${TARGET_XML}.bak"

# === MODIFY TEMPLATE CONFIGURATION ===
log_message "Modifying template configuration..."
# Update WAN IP, subnet and gateway reference
sed -i '' -E "/<interfaces>/,/<\/interfaces>/ {
  /<wan>/,/<\/wan>/ {
    s|<ipaddr>.*</ipaddr>|<ipaddr>${IP}</ipaddr>|
    s|<subnet>.*</subnet>|<subnet>${SUBNET}</subnet>|
    s|<gateway>.*</gateway>|<gateway>WAN_GW</gateway>|
  }
}" "$TEMPLATE_XML"

# Update WAN_GW gateway IP
sed -i '' -E "/<gateways>/,/<\/gateways>/ {
  /<gateway_item>/,/<\/gateway_item>/ {
    /<name>WAN_GW<\/name>/ {
      s|<gateway>.*</gateway>|<gateway>${GATEWAY}</gateway>|
    }
  }
}" "$TEMPLATE_XML"

# Update DNS server
sed -i '' -E "/<system>/,/<\/system>/ {
  s|<dnsserver>.*</dnsserver>|<dnsserver>${DNS}</dnsserver>|
}" "$TEMPLATE_XML"

log_message "Template configuration modified successfully."

# === APPLY TEMPLATE TO ACTIVE CONFIG ===
cp "$TEMPLATE_XML" "$TARGET_XML"
log_message "[✔] Applied template config to ${TARGET_XML}"

# === MARK EXECUTION TO PREVENT REPETITION ===
touch "$BOOT_FLAG_FILE"
log_message "Marked to not execute on future boots."

# === REBOOT TO APPLY ===
log_message "[↻] Rebooting OPNsense to apply new configuration..."
sleep 5 # Increase time to ensure log is saved before reboot
reboot