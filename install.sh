#!/bin/bash
#
# MT7902 DKMS driver - Full installation script
# Installs firmware + builds and installs the DKMS kernel modules
#
# Usage:
#   sudo bash install.sh          # Install for current kernel
#   sudo bash install.sh --uninstall  # Remove everything
#

set -euo pipefail

MODULE_NAME="mt7902"
MODULE_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_LINK="/usr/src/${MODULE_NAME}-${MODULE_VERSION}"
FW_DIR="/lib/firmware/mediatek"
FW_RAM="WIFI_RAM_CODE_MT7902_1.bin"
FW_PATCH="WIFI_MT7902_patch_mcu_1_1_hdr.bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_dependencies() {
    info "Checking dependencies..."
    local missing=()

    for pkg in dkms build-essential wget; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    local headers="linux-headers-$(uname -r)"
    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        missing+=("$headers")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        info "Installing missing packages: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
    else
        info "All dependencies satisfied"
    fi
}

install_firmware() {
    info "Checking firmware..."

    local GH_BASE="https://raw.githubusercontent.com/OnlineLearningTutorials/mt7902_temp/main/mt7902_firmware/latest"

    if [[ -f "$FW_DIR/$FW_RAM" && -f "$FW_DIR/$FW_PATCH" ]]; then
        info "Firmware already installed:"
        ls -la "$FW_DIR/$FW_RAM" "$FW_DIR/$FW_PATCH"
        return 0
    fi

    info "Downloading MT7902 firmware from GitHub..."
    mkdir -p "$FW_DIR"

    for fw in "$FW_RAM" "$FW_PATCH"; do
        if [[ -f "$FW_DIR/$fw" ]]; then
            info "  Already exists: $fw"
            continue
        fi
        info "  Downloading $fw..."
        wget -q --show-progress -O "$FW_DIR/$fw" "$GH_BASE/$fw" || \
            error "Failed to download $fw. Check your internet connection."
    done

    info "Firmware installed:"
    ls -la "$FW_DIR/$FW_RAM" "$FW_DIR/$FW_PATCH"
}

setup_dkms_source() {
    info "Setting up DKMS source link..."

    if [[ -L "$SRC_LINK" ]]; then
        local current_target
        current_target="$(readlink -f "$SRC_LINK")"
        if [[ "$current_target" == "$SCRIPT_DIR" ]]; then
            info "Source link already correct: $SRC_LINK -> $SCRIPT_DIR"
            return 0
        fi
        rm -f "$SRC_LINK"
    elif [[ -e "$SRC_LINK" ]]; then
        warn "Removing existing $SRC_LINK"
        rm -rf "$SRC_LINK"
    fi

    ln -s "$SCRIPT_DIR" "$SRC_LINK"
    info "Created: $SRC_LINK -> $SCRIPT_DIR"
}

build_and_install() {
    info "Registering with DKMS..."

    if dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION" 2>/dev/null | grep -q "$MODULE_NAME"; then
        warn "Removing previous DKMS registration..."
        dkms remove -m "$MODULE_NAME" -v "$MODULE_VERSION" --all 2>/dev/null || true
    fi

    dkms add -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "Building modules (this may take a minute)..."
    dkms build -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "Installing modules..."
    dkms install -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "DKMS status:"
    dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION"
}

load_modules() {
    info "Loading kernel modules..."

    local modules_unload="mt7921e mt7921-common mt792x-lib mt76-connac-lib mt76"
    for mod in $modules_unload; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    modprobe mt7921e

    if lsmod | grep -q mt7921e; then
        info "Driver loaded successfully!"
    else
        warn "mt7921e module loaded but may not have bound to any device"
        warn "Check 'lspci -nnk | grep -A3 7902' and 'dmesg | tail -30'"
    fi
}

show_status() {
    echo ""
    info "=== Installation complete ==="
    echo ""

    echo "Kernel modules:"
    lsmod | grep -E 'mt76|mt7921|mt792x' 2>/dev/null || echo "  (none loaded)"
    echo ""

    echo "PCI device status:"
    lspci -nnk 2>/dev/null | grep -A3 -i '7902' || echo "  No MT7902 device found (is this the right machine?)"
    echo ""

    echo "Recent dmesg:"
    dmesg | grep -i 'mt79' | tail -10 || echo "  (no mt79 messages)"
    echo ""

    info "If WiFi doesn't work, check:"
    echo "  1. Firmware: ls -la /lib/firmware/mediatek/*MT7902*"
    echo "  2. Device:   lspci -nn | grep -i network"
    echo "  3. Logs:     dmesg | grep -i mt79"
}

do_uninstall() {
    info "Uninstalling MT7902 DKMS driver..."

    local modules_unload="mt7921e mt7921-common mt792x-lib mt76-connac-lib mt76"
    for mod in $modules_unload; do
        modprobe -r "$mod" 2>/dev/null || true
    done

    if dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION" 2>/dev/null | grep -q "$MODULE_NAME"; then
        dkms remove -m "$MODULE_NAME" -v "$MODULE_VERSION" --all
        info "DKMS modules removed"
    else
        info "No DKMS registration found"
    fi

    if [[ -L "$SRC_LINK" ]]; then
        rm -f "$SRC_LINK"
        info "Removed source link: $SRC_LINK"
    fi

    info "Uninstall complete. Firmware files left in $FW_DIR (remove manually if desired)"
    info "Reboot or run 'sudo modprobe mt7921e' to load the in-kernel driver"
}

main() {
    echo "=========================================="
    echo " MT7902 WiFi 6E DKMS Driver Installer"
    echo " Based on upstream mt76/mt7921 (kernel v6.17)"
    echo "=========================================="
    echo ""

    check_root

    if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
        do_uninstall
        exit 0
    fi

    local kver
    kver="$(uname -r)"
    info "Kernel: $kver"
    info "Source: $SCRIPT_DIR"

    local kver_major kver_minor
    kver_major="$(echo "$kver" | cut -d. -f1)"
    kver_minor="$(echo "$kver" | cut -d. -f2)"

    if [[ "$kver_major" -lt 6 ]] || { [[ "$kver_major" -eq 6 ]] && [[ "$kver_minor" -lt 17 ]]; }; then
        warn "Kernel $kver is older than 6.17. This driver was built for 6.17+."
        warn "It may not compile or work correctly on older kernels."
        read -rp "Continue anyway? [y/N] " answer
        [[ "$answer" =~ ^[Yy] ]] || exit 1
    fi

    check_dependencies
    install_firmware
    setup_dkms_source
    build_and_install
    load_modules
    show_status
}

main "$@"
