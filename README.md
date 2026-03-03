# MT7902 WiFi 6E Driver for Ubuntu 24.04+

Out-of-tree DKMS driver for the **MediaTek MT7902** PCIe WiFi 6E card, based on MediaTek's gen4-mt79xx driver.

## Supported Hardware

| PCI ID | Description |
|--------|-------------|
| `14c3:7902` | MediaTek MT7902 WiFi 6E |

## Quick Install

```bash
git clone https://github.com/alexiscaspell/mt7902-ubuntu-2404.git
cd mt7902-ubuntu-2404
sudo bash install.sh
```

The script handles everything: dependencies, firmware, DKMS build, module loading, and Secure Boot MOK enrollment if needed.

## Uninstall

```bash
sudo bash install.sh --uninstall
```

## Manual Install

```bash
# Build
make -j$(nproc)

# Install module
sudo make install -j$(nproc)

# Install firmware
sudo make install_fw

# Reboot
sudo reboot
```

## DKMS (auto-rebuild on kernel updates)

The `install.sh` script uses DKMS automatically. For manual DKMS setup:

```bash
sudo apt install dkms build-essential linux-headers-$(uname -r)
sudo ln -s $(pwd) /usr/src/mt7902-1.0.0
sudo dkms add -m mt7902 -v 1.0.0
sudo dkms build -m mt7902 -v 1.0.0
sudo dkms install -m mt7902 -v 1.0.0
sudo make install_fw
sudo reboot
```

## Secure Boot

If Secure Boot is enabled, the install script will automatically detect the module rejection and guide you through MOK key enrollment. You'll need to reboot and enroll the key in the MOK Manager screen.

## Known Issues

- WPA3 may not work with `iwd`; use `wpa_supplicant` instead
- S3 suspend may cause black screen on wake; s2idle works
- If WiFi is flaky, restart the machine or `sudo rmmod mt7902 && sudo modprobe mt7902`

## Credits

- Driver source: [gen4-mt7902](https://github.com/hmtheboy154/gen4-mt7902) by hmtheboy154
- Based on MediaTek gen4-mt79xx from [Xiaomi rodin BSP](https://github.com/MiCode/MTK_kernel_modules)
- Firmware: MediaTek
