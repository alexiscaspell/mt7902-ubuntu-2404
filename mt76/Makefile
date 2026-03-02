# SPDX-License-Identifier: ISC
#
# Out-of-tree Makefile for mt76 mt7921/mt7902 DKMS build
# Based on upstream kernel v6.17 mt76 driver
#

KVER  ?= $(shell uname -r)
KDIR  ?= /lib/modules/$(KVER)/build
PWD   := $(shell pwd)

obj-m += mt76.o
obj-m += mt76-connac-lib.o
obj-m += mt792x-lib.o
obj-m += mt7921-common.o
obj-m += mt7921e.o

# --- mt76 core ---
mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

# --- mt76-connac-lib ---
mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

# --- mt792x-lib ---
mt792x-lib-y := \
	mt792x_core.o mt792x_mac.o mt792x_trace.o \
	mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

# --- mt7921-common (includes MT7902 support) ---
mt7921-common-y := \
	mt7921/mac.o mt7921/mcu.o mt7921/main.o mt7921/init.o \
	mt7921/debugfs.o
mt7921-common-$(CONFIG_NL80211_TESTMODE) += mt7921/testmode.o

# --- mt7921e PCIe driver ---
mt7921e-y := mt7921/pci.o mt7921/pci_mac.o mt7921/pci_mcu.o

# Tracepoint headers need -I$(src)
CFLAGS_trace.o := -I$(src)
CFLAGS_mt792x_trace.o := -I$(src)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install: all
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

.PHONY: all clean install
