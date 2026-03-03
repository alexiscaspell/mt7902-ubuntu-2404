#!/bin/bash
#
# MT7902 gen4 driver - Full installation script
# Installs firmware + builds and installs the DKMS kernel module
#
# Usage:
#   sudo bash install.sh             # Install
#   sudo bash install.sh --uninstall # Remove everything
#

set -euo pipefail

MODULE_NAME="mt7902"
MODULE_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_LINK="/usr/src/${MODULE_NAME}-${MODULE_VERSION}"
FW_DIR="/lib/firmware/mediatek/mt7902"

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

    for pkg in dkms build-essential mokutil; do
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
    info "Installing firmware..."
    mkdir -p "$FW_DIR"

    local fw_src="$SCRIPT_DIR/firmware"
    if [[ ! -d "$fw_src" ]]; then
        error "Firmware directory not found: $fw_src"
    fi

    local count=0
    for fw in "$fw_src"/*.bin; do
        [[ -f "$fw" ]] || continue
        local fname
        fname="$(basename "$fw")"
        cp -v "$fw" "$FW_DIR/$fname"
        count=$((count + 1))
    done

    if [[ $count -eq 0 ]]; then
        error "No firmware .bin files found in $fw_src"
    fi

    info "Installed $count firmware file(s) to $FW_DIR"
}

remove_old_mt76_dkms() {
    if dkms status -m "mt7902" -v "1.0.0" 2>/dev/null | grep -q "mt7902"; then
        local old_src="/usr/src/mt7902-1.0.0"
        if [[ -d "$old_src/mt76" ]]; then
            warn "Removing old mt76-based DKMS module..."
            dkms remove -m mt7902 -v 1.0.0 --all 2>/dev/null || true
            rm -rf "$old_src"
        fi
    fi

    local dkms_updates="/lib/modules/$(uname -r)/updates/dkms"
    rm -f "$dkms_updates"/mt76*.ko.zst 2>/dev/null || true
    rm -f "$dkms_updates"/mt792*.ko.zst 2>/dev/null || true
    rm -f "$dkms_updates"/mt7921*.ko.zst 2>/dev/null || true

    rm -f /etc/modprobe.d/blacklist-mt7902.conf 2>/dev/null || true
}

blacklist_mt76_modules() {
    info "Blacklisting in-kernel mt76 modules to avoid conflicts..."
    cat > /etc/modprobe.d/blacklist-mt76-mt7902.conf <<'CONF'
# Prevent in-kernel mt76 modules from loading (conflicts with gen4 mt7902 driver)
blacklist mt7921e
blacklist mt7921_common
blacklist mt792x_lib
blacklist mt76_connac_lib
blacklist mt76
CONF
}

enable_autoload() {
    info "Enabling mt7902 module autoload at boot..."
    echo "mt7902" > /etc/modules-load.d/mt7902.conf
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

clean_dkms() {
    dkms remove -m "$MODULE_NAME" -v "$MODULE_VERSION" --all 2>/dev/null || true
    rm -rf "/var/lib/dkms/${MODULE_NAME}/${MODULE_VERSION}" 2>/dev/null || true
    rm -rf "/var/lib/dkms/${MODULE_NAME}" 2>/dev/null || true
}

build_and_install() {
    info "Registering with DKMS..."

    local dkms_state
    dkms_state="$(dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION" 2>/dev/null || true)"
    local dkms_tree="/var/lib/dkms/${MODULE_NAME}/${MODULE_VERSION}"

    if [[ -n "$dkms_state" || -d "$dkms_tree" ]]; then
        warn "DKMS already contains ${MODULE_NAME}-${MODULE_VERSION}"
        [[ -n "$dkms_state" ]] && echo "  Status: $dkms_state"
        echo ""
        read -rp "Overwrite existing installation? [Y/n] " answer
        if [[ "$answer" =~ ^[Nn] ]]; then
            info "Skipping DKMS build. Existing installation kept."
            return 0
        fi
        info "Removing previous DKMS registration..."
        clean_dkms
    fi

    dkms add -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "Building module (this may take a few minutes)..."
    dkms build -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "Installing module..."
    dkms install -m "$MODULE_NAME" -v "$MODULE_VERSION"

    info "DKMS status:"
    dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION"
}

enroll_mok_key() {
    local mok_der="/var/lib/shim-signed/mok/MOK.der"

    if [[ ! -f "$mok_der" ]]; then
        error "MOK key not found at $mok_der. Cannot enroll for Secure Boot."
    fi

    warn "Secure Boot is blocking unsigned/untrusted kernel modules."
    warn "We need to enroll the DKMS signing key into your UEFI firmware."
    echo ""
    info "You will be asked to set a ONE-TIME password."
    info "Remember it — you'll need it on the next reboot."
    echo ""

    mokutil --import "$mok_der"

    echo ""
    info "MOK key enrolled. To complete the process:"
    echo ""
    echo "  1. Reboot the machine"
    echo "  2. A blue 'MOK Manager' screen will appear"
    echo "  3. Select 'Enroll MOK' -> 'Continue' -> 'Yes'"
    echo "  4. Enter the password you just set"
    echo "  5. Select 'Reboot'"
    echo ""
    info "After reboot, the driver will load automatically."
    info "You can verify with: lsmod | grep mt7902"
    echo ""

    read -rp "Reboot now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy] ]]; then
        info "Rebooting..."
        reboot
    else
        info "Remember to reboot to complete MOK enrollment."
    fi
}

is_secure_boot_enabled() {
    if command -v mokutil &>/dev/null; then
        mokutil --sb-state 2>/dev/null | grep -qi "secureboot enabled" && return 0
    fi
    return 1
}

try_unload() {
    local mod="$1"
    lsmod | grep -q "^${mod}[[:space:]]" || return 0
    timeout 5 modprobe -r "$mod" 2>/dev/null || true
}

load_module() {
    info "Loading kernel module..."

    try_unload mt7902

    local modules_unload="mt7921e mt7921_common mt792x_lib mt76_connac_lib mt76"
    for mod in $modules_unload; do
        try_unload "$mod"
    done

    if lsmod | grep -q "^mt7902[[:space:]]"; then
        info "Driver already loaded"
        return 0
    fi

    local modprobe_output
    if modprobe_output="$(modprobe mt7902 2>&1)"; then
        if lsmod | grep -q mt7902; then
            info "Driver loaded successfully!"
        else
            warn "modprobe succeeded but module not in lsmod"
            warn "Check 'dmesg | tail -30' for details"
        fi
    else
        if echo "$modprobe_output" | grep -qi "key was rejected\|required key not available"; then
            warn "Module loading rejected: $modprobe_output"
            echo ""
            if is_secure_boot_enabled; then
                info "Secure Boot is enabled. The DKMS signing key needs to be enrolled."
                enroll_mok_key
            else
                error "Module signature rejected but Secure Boot appears disabled. Check 'dmesg | tail -30' for details."
            fi
        else
            error "Failed to load mt7902: $modprobe_output"
        fi
    fi
}

show_status() {
    echo ""
    info "=== Installation complete ==="
    echo ""

    echo "Kernel module:"
    lsmod | grep -E 'mt7902' 2>/dev/null || echo "  (not loaded)"
    echo ""

    echo "PCI device status:"
    lspci -nnk 2>/dev/null | grep -A3 -i '7902' || echo "  No MT7902 device found"
    echo ""

    echo "WiFi interface:"
    ip link show 2>/dev/null | grep -E 'wlan|wlp' || echo "  No WiFi interface found (may appear after reboot)"
    echo ""

    echo "Recent dmesg:"
    dmesg 2>/dev/null | grep -iE 'mt7902|wlan' | tail -10 || echo "  (no messages)"
    echo ""
}

do_uninstall() {
    info "Uninstalling MT7902 gen4 driver..."

    modprobe -r mt7902 2>/dev/null || true

    if dkms status -m "$MODULE_NAME" -v "$MODULE_VERSION" 2>/dev/null | grep -q "$MODULE_NAME"; then
        dkms remove -m "$MODULE_NAME" -v "$MODULE_VERSION" --all
        info "DKMS module removed"
    else
        info "No DKMS registration found"
    fi

    if [[ -L "$SRC_LINK" ]]; then
        rm -f "$SRC_LINK"
        info "Removed source link: $SRC_LINK"
    fi

    rm -f /etc/modprobe.d/blacklist-mt76-mt7902.conf 2>/dev/null || true
    rm -f /etc/modules-load.d/mt7902.conf 2>/dev/null || true
    info "Removed mt76 blacklist and autoload config"

    info "Uninstall complete. Firmware files left in $FW_DIR (remove manually if desired)"
    info "Reboot to restore the in-kernel mt76 driver"
}

main() {
    echo "=========================================="
    echo " MT7902 WiFi 6E Driver Installer"
    echo " Based on MediaTek gen4-mt79xx"
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
    echo ""

    check_dependencies
    install_firmware
    remove_old_mt76_dkms
    blacklist_mt76_modules
    enable_autoload
    setup_dkms_source
    build_and_install
    load_module
    show_status
}

main "$@"
