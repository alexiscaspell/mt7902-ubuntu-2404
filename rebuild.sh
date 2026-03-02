#!/bin/bash

MODULE_NAME="mt7902"
MODULE_VERSION="1.0.0"

MODULES="mt7921e mt7921-common mt792x-lib mt76-connac-lib mt76"

echo "=== Current DKMS status ==="
sudo dkms status --verbose -m $MODULE_NAME -v $MODULE_VERSION

echo "=== Removing previous DKMS build ==="
sudo dkms uninstall --verbose -m $MODULE_NAME -v $MODULE_VERSION 2>/dev/null
sudo dkms remove --verbose -m $MODULE_NAME -v $MODULE_VERSION --all 2>/dev/null

echo "=== Building and installing ==="
sudo dkms add --verbose -m $MODULE_NAME -v $MODULE_VERSION
sudo dkms build --verbose -m $MODULE_NAME -v $MODULE_VERSION
sudo dkms install --verbose -m $MODULE_NAME -v $MODULE_VERSION

echo "=== DKMS status ==="
sudo dkms status --verbose -m $MODULE_NAME -v $MODULE_VERSION

echo "=== Unloading old modules ==="
for mod in $MODULES; do
    sudo modprobe -r "$mod" 2>/dev/null
done

echo "=== Loading new modules ==="
sudo modprobe mt76
sudo modprobe mt76-connac-lib
sudo modprobe mt792x-lib
sudo modprobe mt7921-common
sudo modprobe mt7921e

echo "=== Done. Check dmesg for driver messages ==="
dmesg | tail -20
