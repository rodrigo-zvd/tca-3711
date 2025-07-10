#!/bin/bash

# ==============================================================================
# Script to Generate XCP-ng Installation Answer Files
# This script reads configuration from environment variables.
# ==============================================================================

# --- FUNCTIONS ---

# Function to display an error message and exit
error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- ENVIRONMENT VARIABLE VALIDATION ---
# Checks if the necessary environment variables are set
: "${TEMPLATE_IP?ERROR: TEMPLATE_IP environment variable is not set or empty.}"
: "${TEMPLATE_SUBNET?ERROR: TEMPLATE_SUBNET environment variable is not set or empty.}"
: "${TEMPLATE_GATEWAY?ERROR: TEMPLATE_GATEWAY environment variable is not set or empty.}"
: "${TEMPLATE_NAME_SERVER?ERROR: TEMPLATE_NAME_SERVER environment variable is not set or empty.}"
: "${TEMPLATE_ROOT_PASSWORD?ERROR: TEMPLATE_ROOT_PASSWORD environment variable is not set or empty.}"
: "${TEMPLATE_KEYMAP?ERROR: TEMPLATE_KEYMAP environment variable is not set or empty.}"
: "${TEMPLATE_PRIMARY_DISK?ERROR: PRIMARY_DISK environment variable is not set or empty.}"
: "${TEMPLATE_TIMEZONE?ERROR: TEMPLATE_TIMEZONE environment variable is not set or empty.}"
: "${ANSWERFILE_OUTPUT_DIR?ERROR: ANSWERFILE_OUTPUT_DIR environment variable is not set or empty.}"

# --- SCRIPT START ---

echo "--- XCP-ng Answer File Generator ---"
echo "Reading configurations from environment variables."
echo "Output directory: ./$ANSWERFILE_OUTPUT_DIR/"
echo ""

# Create the output directory if it doesn't exist
if [ ! -d "$ANSWERFILE_OUTPUT_DIR" ]; then
    echo "Creating output directory: $ANSWERFILE_OUTPUT_DIR"
    mkdir -p "$ANSWERFILE_OUTPUT_DIR" || error_exit "Failed to create directory $ANSWERFILE_OUTPUT_DIR."
fi

OUTPUT_FILENAME="$ANSWERFILE_OUTPUT_DIR/answerfile.xml"

echo "Generating file: $OUTPUT_FILENAME"
# XML file content using a here-document
cat << EOF > "$OUTPUT_FILENAME"
<?xml version="1.0"?>
    <installation mode="fresh">
        <primary-disk>$TEMPLATE_PRIMARY_DISK</primary-disk>
        <keymap>$TEMPLATE_KEYMAP</keymap>
        <root-password>$TEMPLATE_ROOT_PASSWORD</root-password>
        <source type="local">repo</source>
        <admin-interface name="eth0" proto="static">
          <ipaddr>$TEMPLATE_IP</ipaddr>
          <subnet>$TEMPLATE_SUBNET</subnet>
          <gateway>$TEMPLATE_GATEWAY</gateway>
        </admin-interface>
        <name-server>$TEMPLATE_NAME_SERVER</name-server>
        <hostname>xcp</hostname>
        <timezone>$TEMPLATE_TIMEZONE</timezone>
    </installation>
EOF
# Check if the file was created successfully
if [ $? -ne 0 ]; then
    error_exit "Failed to write XML file $OUTPUT_FILENAME."
fi

echo ""
echo "--- File Generation Complete! ---"
echo "The XML files have been generated in ./$ANSWERFILE_OUTPUT_DIR/"

exit 0