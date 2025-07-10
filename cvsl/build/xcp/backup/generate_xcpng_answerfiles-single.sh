#!/bin/bash

# ==============================================================================
# Script to Generate XCP-ng Installation Answer Files
# ==============================================================================

# --- NETWORK CONFIGURATIONS (Same for all instances) ---
IP_ADDR="192.168.1.49"     # IP address for the admin interface
SUBNET="255.255.255.0"     # Subnet mask
GATEWAY="192.168.1.1"      # Default gateway
NAME_SERVER="192.168.1.2"  # Primary DNS server (can be comma-separated for multiple)

# --- OTHER INSTALLATION CONFIGURATIONS ---
ROOT_PASSWORD="mypassword" # Password for the root user on XCP-ng (change to a strong password!)
KEYMAP="br-abnt2"          # Keyboard layout (e.g., us, gb, de, fr, br-abnt2)
PRIMARY_DISK="sda"         # Primary disk where XCP-ng will be installed (e.g., sda, vda)
TIMEZONE="America/Sao_Paulo" # Timezone (e.g., America/New_York, Europe/London, Asia/Tokyo)

# --- OUTPUT DIRECTORY ---
OUTPUT_DIR="answerfile"

# --- FUNCTIONS ---

# Function to display an error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- SCRIPT START ---

echo "--- XCP-ng Answer File Generator ---"
echo "Output directory: ./$OUTPUT_DIR/"
echo ""

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR" || error_exit "Failed to create directory $OUTPUT_DIR."
fi

OUTPUT_FILENAME="$OUTPUT_DIR/answerfile.xml"

echo "Generating file: $OUTPUT_FILENAME"
# XML file content using a here-document
cat << EOF > "$OUTPUT_FILENAME"
<?xml version="1.0"?>
    <installation mode="fresh">
        <primary-disk>$PRIMARY_DISK</primary-disk>
        <keymap>$KEYMAP</keymap>
        <root-password>$ROOT_PASSWORD</root-password>
        <source type="local">repo</source>
        <admin-interface name="eth0" proto="static">
          <ipaddr>$IP_ADDR</ipaddr>
          <subnet>$SUBNET</subnet>
          <gateway>$GATEWAY</gateway>
        </admin-interface>
        <name-server>$NAME_SERVER</name-server>
        <hostname>xcp</hostname>
        <timezone>$TIMEZONE</timezone>
    </installation>
EOF
# Check if the file was created successfully
if [ $? -ne 0 ]; then
    error_exit "Failed to write XML file $OUTPUT_FILENAME."
fi

echo ""
echo "--- File Generation Complete! ---"
echo "The $OUTPUT_FILENAME XML files have been generated in ./$OUTPUT_DIR/"

exit 0