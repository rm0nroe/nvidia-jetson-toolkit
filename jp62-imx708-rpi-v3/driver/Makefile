# Makefile for IMX708 Camera Driver - JetPack 6.2
# Supports native build on Jetson Orin Nano
#
# Usage:
#   make              - Build kernel module and device tree overlay
#   make modules      - Build kernel module only
#   make dtbo         - Build device tree overlay only
#   make install      - Install module and overlay
#   make uninstall    - Remove installed files
#   make clean        - Clean build artifacts

DRIVER_NAME := nv_imx708

# Detect kernel version and source
KERNEL_VER ?= $(shell uname -r)
KERNEL_SRC ?= /lib/modules/$(KERNEL_VER)/build

# NVIDIA out-of-tree source locations for JetPack 6.2
# These paths contain tegra_v4l2_camera.h and tegracam_core.h
NVIDIA_OOT_SRC ?= /usr/src/nvidia/nvidia-oot
NVIDIA_SRC ?= /usr/src/nvidia

# Installation paths
MODULE_INSTALL_DIR := /lib/modules/$(KERNEL_VER)/updates/drivers/media/i2c
DTBO_INSTALL_DIR := /boot

# Camera port selection: CAM0 or CAM1 (default: CAM1 for JetPack 6.2)
CAM_PORT ?= CAM1

# Device tree source based on camera port
ifeq ($(CAM_PORT),CAM1)
    DTS_FILE := dts/tegra234-camera-imx708-orin-nano-cam1.dts
    DTBO_FILE := tegra234-camera-imx708-orin-nano-cam1.dtbo
else
    DTS_FILE := dts/tegra234-camera-imx708-orin-nano.dts
    DTBO_FILE := tegra234-camera-imx708-orin-nano.dtbo
endif

PWD := $(shell pwd)

.PHONY: all modules dtbo clean install uninstall help

all: modules dtbo

modules:
	@echo "Building kernel module for kernel $(KERNEL_VER)..."
	@if [ ! -d "$(KERNEL_SRC)" ]; then \
		echo "Error: Kernel headers not found at $(KERNEL_SRC)"; \
		echo "Install with: sudo apt install nvidia-l4t-kernel-headers"; \
		exit 1; \
	fi
	@if [ ! -d "$(NVIDIA_OOT_SRC)/include" ]; then \
		echo "Error: NVIDIA OOT headers not found at $(NVIDIA_OOT_SRC)"; \
		echo "Install with: sudo apt install nvidia-l4t-kernel-oot-headers"; \
		exit 1; \
	fi
	@if [ ! -f "$(NVIDIA_OOT_SRC)/Module.symvers" ]; then \
		echo "Error: NVIDIA OOT Module.symvers not found at $(NVIDIA_OOT_SRC)/Module.symvers"; \
		echo "This file contains symbol exports needed for tegracam framework"; \
		echo "Install with: sudo apt install nvidia-l4t-kernel-oot-headers"; \
		exit 1; \
	fi
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD)/src \
		NVIDIA_OOT_SRC=$(NVIDIA_OOT_SRC) \
		NVIDIA_SRC=$(NVIDIA_SRC) \
		KBUILD_EXTRA_SYMBOLS=$(NVIDIA_OOT_SRC)/Module.symvers \
		modules

dtbo: $(DTBO_FILE)

$(DTBO_FILE): $(DTS_FILE)
	@echo "Building device tree overlay..."
	@if ! command -v dtc >/dev/null 2>&1; then \
		echo "Error: dtc (device-tree-compiler) not found"; \
		echo "Install with: sudo apt install device-tree-compiler"; \
		exit 1; \
	fi
	dtc -O dtb -o $@ -@ $<
	@echo "Built: $@"

clean:
	@echo "Cleaning build artifacts..."
	$(MAKE) -C $(KERNEL_SRC) M=$(PWD)/src clean 2>/dev/null || true
	rm -f $(DTBO_FILE)
	rm -f src/*.o src/*.ko src/*.mod* src/.*.cmd src/modules.order src/Module.symvers
	rm -rf src/.tmp_versions

install: all
	@echo "Installing IMX708 driver..."
	@echo "Creating module directory: $(MODULE_INSTALL_DIR)"
	sudo mkdir -p $(MODULE_INSTALL_DIR)
	@echo "Installing kernel module..."
	sudo cp src/$(DRIVER_NAME).ko $(MODULE_INSTALL_DIR)/
	@echo "Installing device tree overlay..."
	sudo cp $(DTBO_FILE) $(DTBO_INSTALL_DIR)/
	@echo "Updating module dependencies..."
	sudo depmod -a
	@echo "Creating module autoload config..."
	echo "$(DRIVER_NAME)" | sudo tee /etc/modules-load.d/imx708.conf > /dev/null
	@echo ""
	@echo "============================================="
	@echo "Installation complete!"
	@echo ""
	@echo "IMPORTANT: You must configure the bootloader to load the overlay."
	@echo "Edit /boot/extlinux/extlinux.conf and add after the FDT line:"
	@echo "      OVERLAYS $(DTBO_INSTALL_DIR)/$(DTBO_FILE)"
	@echo ""
	@echo "Then reboot: sudo reboot"
	@echo "============================================="

uninstall:
	@echo "Uninstalling IMX708 driver..."
	sudo rm -f $(MODULE_INSTALL_DIR)/$(DRIVER_NAME).ko
	sudo rm -f $(DTBO_INSTALL_DIR)/$(DTBO_FILE)
	sudo rm -f /etc/modules-load.d/imx708.conf
	sudo depmod -a
	@echo "Uninstallation complete."
	@echo "Note: Remember to remove the OVERLAYS line from /boot/extlinux/extlinux.conf"

help:
	@echo "IMX708 Camera Driver Build System - JetPack 6.2"
	@echo ""
	@echo "Targets:"
	@echo "  all       - Build kernel module and device tree overlay (default)"
	@echo "  modules   - Build kernel module only"
	@echo "  dtbo      - Build device tree overlay only"
	@echo "  install   - Install module and overlay to system"
	@echo "  uninstall - Remove installed files"
	@echo "  clean     - Remove build artifacts"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  CAM_PORT       - Camera port: CAM0 or CAM1 (default: CAM1)"
	@echo "                   NOTE: JetPack 6.2 only supports CAM1 for IMX708!"
	@echo "  KERNEL_VER     - Kernel version (default: $(KERNEL_VER))"
	@echo "  KERNEL_SRC     - Kernel source/headers path (default: $(KERNEL_SRC))"
	@echo "  NVIDIA_OOT_SRC - NVIDIA out-of-tree source path (default: $(NVIDIA_OOT_SRC))"
	@echo "  NVIDIA_SRC     - NVIDIA source path (default: $(NVIDIA_SRC))"
	@echo ""
	@echo "Examples:"
	@echo "  make                    - Build for CAM1 (default, recommended)"
	@echo "  make CAM_PORT=CAM0      - Build for CAM0 (not supported on JP6.2)"
	@echo "  make install            - Build and install for CAM1"
	@echo ""
	@echo "Required packages:"
	@echo "  nvidia-l4t-kernel-headers     - Kernel headers for module compilation"
	@echo "  nvidia-l4t-kernel-oot-headers - NVIDIA tegracam headers (tegra_v4l2_camera.h)"
	@echo "  device-tree-compiler          - DTC for device tree overlay compilation"
