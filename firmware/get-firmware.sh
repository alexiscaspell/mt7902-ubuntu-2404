#!/bin/bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW_DIR="/lib/firmware/mediatek"

URL_FILE="$SCRIPT_DIR/acer.url"
URL="$(cat "$URL_FILE")"
ZIP="$(basename "${URL%%\?*}" | sed 'y/+/ /; s/%/\\x/g')"
ZIP="$(echo -e "$ZIP")"

TMPDIR="$(mktemp -d)"
trap "rm -rf '$TMPDIR'" EXIT

echo "Downloading MT7902 firmware from Acer..."
wget -O "$TMPDIR/$ZIP" "$URL"

echo "Extracting firmware..."
unzip -o "$TMPDIR/$ZIP" -d "$TMPDIR"

echo "Installing firmware to $FW_DIR..."
sudo mkdir -p "$FW_DIR"

find "$TMPDIR" -name '*MT7902*' -exec sudo cp -v {} "$FW_DIR/" \;

echo "Installed firmware files:"
ls -la "$FW_DIR"/*MT7902* 2>/dev/null || echo "WARNING: No MT7902 firmware files found in archive"

echo ""
echo "Expected files:"
echo "  $FW_DIR/WIFI_RAM_CODE_MT7902_1.bin"
echo "  $FW_DIR/WIFI_MT7902_patch_mcu_1_1_hdr.bin"
