#!/bin/bash

# ==============================================================================
# Main Script to Generate XCP-ng Answer Files
# This script defines configuration variables and exports them as
# environment variables before calling the generator script.
# ==============================================================================

echo "--- XCP-ng Answer File Generation Main Script ---"
echo ""

# --- NETWORK CONFIGURATIONS (Same for all instances) ---
export TEMPLATE_IP="192.168.1.49"     # IP address for the admin interface
export TEMPLATE_SUBNET="255.255.255.0"     # Subnet mask
export TEMPLATE_GATEWAY="192.168.1.5"      # Default gateway
export TEMPLATE_NAME_SERVER="8.8.8.8"  # Primary DNS server (can be comma-separated for multiple)

# --- OTHER INSTALLATION CONFIGURATIONS ---
export TEMPLATE_ROOT_PASSWORD="123456" # Password for the root user on XCP-ng (change to a strong password!)
export TEMPLATE_KEYMAP="br-abnt2"          # Keyboard layout (e.g., us, gb, de, fr, br-abnt2)
export TEMPLATE_PRIMARY_DISK="sda"         # Primary disk where XCP-ng will be installed (e.g., sda, vda)
export TEMPLATE_TIMEZONE="America/Sao_Paulo" # Timezone (e.g., America/New_York, Europe/London, Asia/Tokyo)

# --- OUTPUT DIRECTORY ---
export ANSWERFILE_OUTPUT_DIR="answerfile" # Directory where the answer file will be saved

echo "Configuration variables defined and exported."
echo "Calling 'generate_answerfile.sh' script..."
echo ""

# Execute the script that actually generates the answer file
# Make sure 'generate_answerfile.sh' is in the PATH
# or provide the full path to it.
./generate_answerfile.sh

# Check the exit code of the called script
if [ $? -ne 0 ]; then
    echo "ERROR: Answer file generation failed."
    exit 1
fi

echo ""
echo "--- Process Completed! ---"

exit 0