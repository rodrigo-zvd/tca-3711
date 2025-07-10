#!/bin/bash

# Documentation:
# https://docs.xcp-ng.org/installation/install-xcp-ng/#unattended-installation-with-a-custom-iso-image
# https://docs.xcp-ng.org/project/development-process/ISO-modification/
# https://docs.xcp-ng.org/appendix/answerfile/

# ==============================================================================
# Script to Create a Customized XCP-ng Unattended-Install ISO
# This script generates a single ISO, pointing to a unique answerfile URL.
# It uses environment variables (XCP_NG_ISO_URL_FILE or XCP_NG_ISO_LOCAL_FILE)
# to determine if it should download an ISO or use a local one.
# Includes mandatory SHA256 checksum verification for the ISO.
#
# Designed to be called by another script, which will export the necessary
# configuration variables as environment variables.
# ==============================================================================

# --- EXPECTED ENVIRONMENT VARIABLES (No default values here) ---
# XCP_NG_ISO_VERSION        # e.g., "8.3.0"
# XCP_NG_ISO_URL_FILE       # URL for the XCP-ng ISO
# XCP_NG_ISO_LOCAL_FILE     # Path to a local XCP-ng ISO file
# XCP_NG_ISO_SHA256         # MANDATORY: Expected SHA256 checksum for the ISO
# ANSWERFILE_URL            # Base URL for your answer file (e.g., "http://192.168.1.110")
# ANSWERFILE_PATH           # Path to the answerfile relative to ANSWERFILE_URL (e.g., "answerfile/answerfile.xml")

# --- DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

# Global cleanup function
function cleanup {
    echo "--- Initiating global cleanup ---" >&2 # Redirect to stderr
    if [ -n "$TMP_ISO_MOUNT" ] && mountpoint -q "$TMP_ISO_MOUNT"; then
        sudo umount "$TMP_ISO_MOUNT"
        rmdir "$TMP_ISO_MOUNT"
        echo "  - Unmounted and removed temporary mount point: $TMP_ISO_MOUNT" >&2
    fi
    if [ -n "$TMP_WORK_DIR" ] && [ -d "$TMP_WORK_DIR" ]; then
        rm -rf "$TMP_WORK_DIR"
        echo "  - Removed temporary work directory: $TMP_WORK_DIR" >&2
    fi
    echo "--- Global cleanup complete ---" >&2
}

# Register global cleanup function to run on exit or script interruption
trap cleanup EXIT INT TERM

# Ensure the output 'isos' directory exists
mkdir -p isos || { echo "Error: Failed to create 'isos' output directory." >&2; exit 1; }

# Check if required commands are available
for cmd in mount umount genisoimage sed cp mkdir rm isohybrid sha256sum; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Command '$cmd' not found. Please install it." >&2
        exit 1
    fi
done

# --- Validate mandatory environment variables ---
if [ -z "$XCP_NG_ISO_VERSION" ]; then
    echo "Error: Environment variable XCP_NG_ISO_VERSION is not set." >&2
    exit 1
fi
if [ -z "$XCP_NG_ISO_SHA256" ]; then
    echo "Error: Environment variable XCP_NG_ISO_SHA256 is not set." >&2
    echo "Please set this variable with the expected SHA256 checksum of your ISO." >&2
    exit 1
fi
if [ -z "$ANSWERFILE_URL" ]; then
    echo "Error: Environment variable ANSWERFILE_URL is not set." >&2
    exit 1
fi
if [ -z "$ANSWERFILE_PATH" ]; then
    echo "Error: Environment variable ANSWERFILE_PATH is not set." >&2
    exit 1
fi

echo "--- Starting XCP-ng Unattended-Install ISO Customization ---"

ORIGINAL_ISO=""

# Determine ISO source (URL or local file)
if [ -n "$XCP_NG_ISO_URL_FILE" ]; then
    echo "  - XCP_NG_ISO_URL_FILE environment variable is set. Attempting to download ISO."
    ISO_DOWNLOAD_URL="$XCP_NG_ISO_URL_FILE"
    
    # Extract filename from URL for DOWNLOADED_ISO_PATH
    DOWNLOADED_ISO_FILENAME=$(basename "$ISO_DOWNLOAD_URL")
    DOWNLOADED_ISO_PATH="isos/${DOWNLOADED_ISO_FILENAME}"

    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        echo "Error: Neither 'wget' nor 'curl' found. Please install one to download the ISO." >&2
        exit 1
    fi

    SKIP_DOWNLOAD=false
    if [ -f "$DOWNLOADED_ISO_PATH" ]; then
        echo "  - Found existing ISO: $DOWNLOADED_ISO_PATH. Verifying SHA256..."
        ACTUAL_CHECKSUM=$(sha256sum "$DOWNLOADED_ISO_PATH" | awk '{print $1}')

        if [ "$XCP_NG_ISO_SHA256" == "$ACTUAL_CHECKSUM" ]; then
            echo "  - Existing ISO SHA256 matches expected checksum. Skipping download."
            SKIP_DOWNLOAD=true
        else
            echo "  - Existing ISO SHA256 MISMATCH. Expected: $XCP_NG_ISO_SHA256, Got: $ACTUAL_CHECKSUM." >&2
            echo "  - Removing existing ISO and re-downloading." >&2
            rm "$DOWNLOADED_ISO_PATH"
        fi
    fi

    if [ "$SKIP_DOWNLOAD" = false ]; then
        echo "  - Downloading ISO from '$ISO_DOWNLOAD_URL' to '$DOWNLOADED_ISO_PATH'..."
        if command -v wget &> /dev/null; then
            wget -q --show-progress -O "$DOWNLOADED_ISO_PATH" "$ISO_DOWNLOAD_URL"
        elif command -v curl &> /dev/null; then
            curl -L -o "$DOWNLOADED_ISO_PATH" "$ISO_DOWNLOAD_URL"
        fi

        if [ $? -ne 0 ]; then
            echo "Error: Failed to download ISO from '$ISO_DOWNLOAD_URL'." >&2
            exit 1
        fi
        echo "  - ISO downloaded successfully."
    fi
    ORIGINAL_ISO="$DOWNLOADED_ISO_PATH"

elif [ -n "$XCP_NG_ISO_LOCAL_FILE" ]; then
    echo "  - XCP_NG_ISO_LOCAL_FILE environment variable is set. Using local ISO."
    ORIGINAL_ISO="$XCP_NG_ISO_LOCAL_FILE"
    if [ ! -f "$ORIGINAL_ISO" ]; then
        echo "Error: Local ISO '$ORIGINAL_ISO' not found as specified by XCP_NG_ISO_LOCAL_FILE." >&2
        exit 1
    fi
else
    echo "Error: Neither XCP_NG_ISO_URL_FILE nor XCP_NG_ISO_LOCAL_FILE is set." >&2
    echo "Please set ONE of them with your local ISO path or the download URL." >&2
    exit 1
fi

# --- PERFORM SHA256 CHECK FOR THE SELECTED ISO ---
echo ""
echo "--- Verifying SHA256 checksum of the selected ISO: $ORIGINAL_ISO ---"
ACTUAL_CHECKSUM=$(sha256sum "$ORIGINAL_ISO" | awk '{print $1}')

if [ "$XCP_NG_ISO_SHA256" == "$ACTUAL_CHECKSUM" ]; then
    echo "  - ISO SHA256 verified successfully. Actual: $ACTUAL_CHECKSUM"
else
    echo "Error: ISO SHA256 MISMATCH!" >&2
    echo "  Expected: $XCP_NG_ISO_SHA256" >&2
    echo "  Actual:   $ACTUAL_CHECKSUM" >&2
    echo "Please ensure you have the correct ISO file or update the XCP_NG_ISO_SHA256 variable." >&2
    exit 1
fi
echo "--- SHA256 verification complete ---"


echo ""
echo "Processing the ISO: $ORIGINAL_ISO"

# Define dynamic variables for the current instance
FULL_ANSWERFILE_URL="${ANSWERFILE_URL}/${ANSWERFILE_PATH}"
CURRENT_OUTPUT_ISO="isos/xcp-ng-${XCP_NG_ISO_VERSION}-unattended-install.iso"

echo "  - Answerfile URL for this ISO: $FULL_ANSWERFILE_URL"
echo "  - Output ISO name: $CURRENT_OUTPUT_ISO"

# Create temporary directories
TMP_ISO_MOUNT=$(mktemp -d -t iso_mnt_XXXXXX)
TMP_WORK_DIR=$(mktemp -d -t iso_work_XXXXXX)

echo "  - Mounting original ISO '$ORIGINAL_ISO' to '$TMP_ISO_MOUNT'..."
sudo mount -o loop "$ORIGINAL_ISO" "$TMP_ISO_MOUNT"
if [ $? -ne 0 ]; then
    echo "Error: Failed to mount ISO. Exiting." >&2
    exit 1
fi

echo "  - Copying ISO contents to '$TMP_WORK_DIR'..."
# Copy everything including hidden files (like .disk)
cp -a "$TMP_ISO_MOUNT"/. "$TMP_WORK_DIR"/
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy ISO contents. Exiting." >&2
    exit 1
fi

# Path to the isolinux.cfg file in the working directory
ISOLINUX_CFG="$TMP_WORK_DIR/boot/isolinux/isolinux.cfg"

if [ ! -f "$ISOLINUX_CFG" ]; then
    echo "Error: isolinux.cfg not found at '$ISOLINUX_CFG'. Is this a valid XCP-ng ISO?" >&2
    exit 1
fi

echo "  - Modifying '$ISOLINUX_CFG' to include answerfile URL: $FULL_ANSWERFILE_URL"

# This awk command targets the 'APPEND' line inside the 'LABEL install' block
# and inserts 'answerfile=<URL> install' before the final '--- /install.img'
awk -v url="$FULL_ANSWERFILE_URL" '
BEGIN { in_label=0 }
/^[[:space:]]*LABEL install[[:space:]]*$/ { in_label=1; print; next }
/^[[:space:]]*LABEL / && in_label { in_label=0 }
in_label && /^[[:space:]]*APPEND / {
  sub(/ ---[[:space:]]*\/install\.img/, " answerfile=" url " install --- /install.img")
}
{ print }
' "$ISOLINUX_CFG" > "${ISOLINUX_CFG}.tmp" && mv "${ISOLINUX_CFG}.tmp" "$ISOLINUX_CFG"

if [ $? -ne 0 ]; then
    echo "Error: Failed to modify '$ISOLINUX_CFG'. Check the awk command or file structure." >&2
    exit 1
fi

echo "  - '$ISOLINUX_CFG' modified successfully. Showing updated 'install' entry:"
sed -n "/^LABEL install/,/^LABEL /p" "$ISOLINUX_CFG" | grep "APPEND" | head -n 1

echo "  - Creating new ISO image '$CURRENT_OUTPUT_ISO' with genisoimage..."

sudo genisoimage -o "$CURRENT_OUTPUT_ISO" -v -r -J --joliet-long -V "XCP-ng $XCP_NG_ISO_VERSION" \
            -c boot/isolinux/boot.cat -b boot/isolinux/isolinux.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -eltorito-alt-boot -e boot/efiboot.img -no-emul-boot "$TMP_WORK_DIR"
            
if [ $? -ne 0 ]; then
    echo "Error: Failed to create initial ISO with genisoimage. Exiting." >&2
    exit 1
fi

echo "  - Running isohybrid --uefi on the new ISO for full UEFI compatibility: $CURRENT_OUTPUT_ISO"
sudo isohybrid --uefi "$CURRENT_OUTPUT_ISO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to make ISO isohybrid. Exiting." >&2
    exit 1
fi

echo "Successfully created bootable ISO: $CURRENT_OUTPUT_ISO (supports BIOS and UEFI)"

echo ""
echo "--- XCP-ng Unattended-Install ISO has been generated! ---"
echo "You can find it in the 'isos/' directory: $CURRENT_OUTPUT_ISO"
echo "Remember to place your 'answerfile.xml' file on your web server at: $FULL_ANSWERFILE_URL"

exit 0