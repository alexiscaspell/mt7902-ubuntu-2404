#!/bin/bash
set -euo pipefail

FW_DIR="/lib/firmware/mediatek"
FW_RAM="WIFI_RAM_CODE_MT7902_1.bin"
FW_PATCH="WIFI_MT7902_patch_mcu_1_1_hdr.bin"

GH_BASE="https://raw.githubusercontent.com/OnlineLearningTutorials/mt7902_temp/main/mt7902_firmware/latest"

echo "Installing MT7902 firmware to $FW_DIR..."
mkdir -p "$FW_DIR"

for fw in "$FW_RAM" "$FW_PATCH"; do
    if [[ -f "$FW_DIR/$fw" ]]; then
        echo "  Already exists: $FW_DIR/$fw"
        continue
    fi

    echo "  Downloading $fw..."
    wget -q --show-progress -O "$FW_DIR/$fw" "$GH_BASE/$fw" || {
        echo "ERROR: Failed to download $fw"
        exit 1
    }
done

echo ""
echo "Firmware installed:"
ls -la "$FW_DIR/$FW_RAM" "$FW_DIR/$FW_PATCH"
