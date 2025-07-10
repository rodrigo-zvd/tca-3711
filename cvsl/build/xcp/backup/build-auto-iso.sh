#!/bin/bash

#Documentation:
#https://docs.xcp-ng.org/installation/install-xcp-ng/#unattended-installation-with-a-custom-iso-image
#https://docs.xcp-ng.org/project/development-process/ISO-modification/
#https://docs.xcp-ng.org/appendix/answerfile/

# Variables for the new genisoimage command
ISO_VERSION="8.3" # Adjust if your XCP-ng version is different
# Configuration Variables
ORIGINAL_ISO="../../isos/xcp-ng-8.3.0.iso" # Replace with your XCP-ng ISO filename
OUTPUT_ISO="isos/xcp-ng-${ISO_VERSION}-autoinstall.iso" # Name for the new ISO
ANSWERFILE_URL="http://192.168.1.110/answerfile.xml" # IMPORTANT: Replace with your actual answerfile URL


# --- DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING ---

# Check if required commands are available
for cmd in mount umount genisoimage sed cp mkdir rm isohybrid; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Command '$cmd' not found. Please install it."
        exit 1
    fi
done

# Check if the original ISO exists
if [ ! -f "$ORIGINAL_ISO" ]; then
    echo "Error: Original ISO '$ORIGINAL_ISO' not found."
    echo "Please make sure it's in the same directory as the script or provide the full path."
    exit 1
fi

# Create temporary directories
TMP_ISO_MOUNT=$(mktemp -d -t iso_mnt_XXXXXX)
TMP_WORK_DIR=$(mktemp -d -t iso_work_XXXXXX)

function cleanup {
    echo "Cleaning up temporary files..."
    if mountpoint -q "$TMP_ISO_MOUNT"; then
        sudo umount "$TMP_ISO_MOUNT"
    fi
    rm -rf "$TMP_ISO_MOUNT"
    rm -rf "$TMP_WORK_DIR"
    echo "Cleanup complete."
}

# Register cleanup function to run on exit or script interruption
trap cleanup EXIT INT TERM

echo "Mounting original ISO '$ORIGINAL_ISO' to '$TMP_ISO_MOUNT'..."
sudo mount -o loop "$ORIGINAL_ISO" "$TMP_ISO_MOUNT"
if [ $? -ne 0 ]; then
    echo "Error: Failed to mount ISO. Exiting."
    exit 1
fi

echo "Copying ISO contents to '$TMP_WORK_DIR'..."
# Copy everything including hidden files (like .disk)
cp -a "$TMP_ISO_MOUNT"/. "$TMP_WORK_DIR"/
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy ISO contents. Exiting."
    exit 1
fi

# Path to the isolinux.cfg file in the working directory
ISOLINUX_CFG="$TMP_WORK_DIR/boot/isolinux/isolinux.cfg"

if [ ! -f "$ISOLINUX_CFG" ]; then
    echo "Error: isolinux.cfg not found at '$ISOLINUX_CFG'. Is this a valid XCP-ng ISO?"
    exit 1
fi

echo "Modifying '$ISOLINUX_CFG' to include answerfile URL..."

# Use sed to find the 'LABEL install' block and append the answerfile parameter
sed -i "/^LABEL install/,/^APPEND / { s|\(---\s*\/boot\/vmlinuz.*\)\(---\s*\/install.img\)|\1 answerfile=${ANSWERFILE_URL} install \2| }" "$ISOLINUX_CFG"
if [ $? -ne 0 ]; then
    echo "Error: Failed to modify isolinux.cfg. Check the sed command or file content."
    exit 1
fi

echo "isolinux.cfg modified successfully. New content for 'install' label:"
# Display the modified section for verification
sed -n "/^LABEL install/,/^APPEND /p" "$ISOLINUX_CFG"

echo "Creating new ISO image '$OUTPUT_ISO' with genisoimage..."

# The genisoimage command from your prompt
# -o: Output file
# -v: Verbose output
# -r: Rock Ridge extensions
# -J: Joliet extensions
# --joliet-long: Allow longer Joliet filenames
# -V "XCP-ng $ISO_VERSION": Volume label
# -c boot/isolinux/boot.cat: Boot catalog for BIOS
# -b boot/isolinux/isolinux.bin: Boot image for BIOS
# -no-emul-boot: No boot emulation
# -boot-load-size 4: Load 4 sectors for BIOS boot
# -boot-info-table: Create boot info table for BIOS
# -eltorito-alt-boot: Enable El Torito "alternate boot" for UEFI
# -e boot/efiboot.img: UEFI boot image
# -no-emul-boot: No boot emulation for UEFI (repeated for clarity, but typically applied once for eltorito)
# .: Source directory (the temporary working directory where the ISO contents are)
sudo genisoimage -o "$OUTPUT_ISO" -v -r -J --joliet-long -V "XCP-ng $ISO_VERSION" \
            -c boot/isolinux/boot.cat -b boot/isolinux/isolinux.bin \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -eltorito-alt-boot -e boot/efiboot.img -no-emul-boot "$TMP_WORK_DIR"
            
if [ $? -ne 0 ]; then
    echo "Error: Failed to create initial ISO with genisoimage. Exiting."
    exit 1
fi

echo "Running isohybrid --uefi on the new ISO for full UEFI compatibility..."
sudo isohybrid --uefi "$OUTPUT_ISO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to make ISO isohybrid. Exiting."
    exit 1
fi

echo "Successfully created bootable ISO: $OUTPUT_ISO (supports BIOS and UEFI)"

# Cleanup will be executed automatically by the trap command

exit 0