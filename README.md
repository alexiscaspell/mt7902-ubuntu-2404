# mt7902-dkms

Out-of-tree DKMS driver for the **MediaTek MT7902** WiFi 6E PCIe wireless chipset, built on top of the upstream mt76/mt7921 driver from kernel v6.17.

## Supported hardware

| PCI ID | Description |
|--------|-------------|
| `14c3:7902` | MediaTek MT7902E (base) |
| `14c3:7902` / sub `14c3:7902` | MicroTek variant |
| `14c3:7902` / sub `14c3:1ede` | MicroTek variant |
| `14c3:7902` / sub `1a3b:5520` | AzureWave variant |
| `14c3:7902` / sub `1a3b:5521` | AzureWave variant |

Check your hardware with `lspci -nn | grep -i network`.

## Requirements

- **Ubuntu 24.04** (Noble Numbat) or compatible Debian-based distro
- **Kernel 6.17** or newer
- **DKMS**: `sudo apt install dkms`

## Quick install (recommended)

```bash
git clone https://github.com/samveen/mt7902-dkms
cd mt7902-dkms
sudo bash install.sh
```

This single command will:
1. Install all dependencies (`dkms`, `build-essential`, kernel headers)
2. Download and install MT7902 firmware from Acer
3. Register, build, and install the DKMS modules
4. Load the driver

To uninstall:

```bash
sudo bash install.sh --uninstall
```

## Manual installation

If you prefer to do it step by step:

### 1. Install firmware

The MT7902 firmware is not yet in `linux-firmware`. Download it from the Acer Windows driver package:

```bash
cd firmware
sudo bash get-firmware.sh
```

This installs the following files to `/lib/firmware/mediatek/`:
- `WIFI_RAM_CODE_MT7902_1.bin`
- `WIFI_MT7902_patch_mcu_1_1_hdr.bin`

### 2. Link the source for DKMS

```bash
sudo ln -s /path/to/mt7902-dkms /usr/src/mt7902-1.0.0
```

### 3. Build and install with DKMS

```bash
sudo dkms add -m mt7902 -v 1.0.0
sudo dkms build -m mt7902 -v 1.0.0
sudo dkms install -m mt7902 -v 1.0.0
```

### 4. Load the driver

```bash
sudo modprobe mt7921e
```

Or reboot. The driver will load automatically when the MT7902 PCI device is detected.

### 5. Verify

```bash
sudo dkms status -m mt7902 -v 1.0.0
lspci -nnk | grep -A3 7902
dmesg | grep -i mt79
```

## Module structure

This DKMS package builds 5 kernel modules that replace the in-tree mt76 stack:

| Module | Description |
|--------|-------------|
| `mt76` | Core mt76 framework |
| `mt76-connac-lib` | MediaTek Connac shared library |
| `mt792x-lib` | MT792x shared library |
| `mt7921-common` | MT7921/MT7902 common driver |
| `mt7921e` | PCIe driver (supports MT7921, MT7922, MT7920, MT7902) |

## Uninstall

```bash
sudo dkms uninstall -m mt7902 -v 1.0.0
sudo dkms remove -m mt7902 -v 1.0.0 --all
sudo rm -rf /usr/src/mt7902-1.0.0
```

## Troubleshooting

### Driver doesn't load

Make sure the in-kernel mt7921e isn't blocking:

```bash
sudo modprobe -r mt7921e mt7921-common mt792x-lib mt76-connac-lib mt76
sudo modprobe mt7921e
```

If needed, blacklist the in-kernel modules by creating `/etc/modprobe.d/mt7902-dkms.conf`:

```
# Force use of DKMS mt76 modules (with MT7902 support)
install mt7921e /sbin/modprobe --ignore-install mt7921e
```

### Firmware not found

Check that firmware files exist:

```bash
ls -la /lib/firmware/mediatek/WIFI_*MT7902*
```

If missing, re-run `sudo bash firmware/get-firmware.sh`.

## Background

The MT7902 is a WiFi 6E chipset found in many laptops from Acer, ASUS, and HP. It belongs to the mt7921 driver family (connac2 generation). Official upstream support was submitted by MediaTek in February 2026 and is expected in Linux v7.1. This DKMS package provides that support for kernel 6.17+.

## License

- Source code: see https://github.com/torvalds/linux/ (ISC / Dual BSD/GPL)
- Firmware: proprietary, owned by MediaTek. Not included in this repository.
