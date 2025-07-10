#!/bin/bash

# ==============================================================================
# Script to Generate XCP-ng Installation Answer Files
# This script now accepts the number of templates as an argument.
# ==============================================================================

# --- GENERAL CONFIGURATIONS ---
# The number of installation files (XCP-ng instances) to be generated.
# This value is now read from the first command-line argument.
# If no argument is provided, it defaults to 1.
XCPNG_TEMPLATE_COUNT=${1:-1}

# Argument validation
if ! [[ "$XCPNG_TEMPLATE_COUNT" =~ ^[0-9]+$ ]] || [ "$XCPNG_TEMPLATE_COUNT" -lt 1 ]; then
    echo "ERROR: The number of templates must be a positive integer (>= 1)." >&2
    echo "Usage: $0 <number_of_templates>" >&2
    exit 1
fi

# --- NETWORK CONFIGURATIONS (Same for all instances) ---
# You can make these variables arguments as well if they need to change per execution.
# ATTENTION: This script uses the same IP for all files. If you need sequential
# IPs (e.g., 192.168.1.49, 192.168.1.50), you'll need to add logic within the loop
# to increment the IP address for each generated file.
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
echo "Template count: $XCPNG_TEMPLATE_COUNT"
echo "Output directory: ./$OUTPUT_DIR/"
echo ""

# Create the output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR" || error_exit "Failed to create directory $OUTPUT_DIR."
fi

# Loop to generate XML files
for (( i=1; i<=$XCPNG_TEMPLATE_COUNT; i++ )); do
    CURRENT_HOSTNAME="xcp$i"
    OUTPUT_FILENAME="$OUTPUT_DIR/answerfile-$CURRENT_HOSTNAME.xml"

    echo "Generating file: $OUTPUT_FILENAME"

    # XML file content using a here-document
    # Variables are expanded by the shell
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
        <hostname>$CURRENT_HOSTNAME</hostname>
        <timezone>$TIMEZONE</timezone>
    </installation>
EOF

    # Check if the file was created successfully
    if [ $? -ne 0 ]; then
        error_exit "Failed to write XML file $OUTPUT_FILENAME."
    fi
done

echo ""
echo "--- File Generation Complete! ---"
echo "The $XCPNG_TEMPLATE_COUNT XML files have been generated in ./$OUTPUT_DIR/"

exit 0