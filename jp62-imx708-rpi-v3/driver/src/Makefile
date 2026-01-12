# Makefile for IMX708 sensor driver - Out of tree build
# JetPack 6.2 (L4T R36.4.x)

obj-m := nv_imx708.o

# NVIDIA OOT headers location for JetPack 6.2
# These are installed by nvidia-l4t-kernel-oot-headers package
NVIDIA_OOT_SRC ?= /usr/src/nvidia/nvidia-oot
NVIDIA_SRC ?= /usr/src/nvidia

# Include paths for tegracam headers
# Primary: NVIDIA out-of-tree modules headers (where tegra_v4l2_camera.h lives)
ccflags-y := -I$(NVIDIA_OOT_SRC)/include
ccflags-y += -I$(NVIDIA_OOT_SRC)/include/media
ccflags-y += -I$(NVIDIA_SRC)/include
# Fallback: Check in kernel source tree (older JetPack versions)
ccflags-y += -I$(KERNEL_SRC)/nvidia-oot/include
ccflags-y += -I$(KERNEL_SRC)/nvidia/include
# Local project headers
ccflags-y += -I$(src)/../include

# Symbol resolution for NVIDIA tegracam framework
# The driver depends on symbols exported by NVIDIA's OOT camera modules
# (tegracam_device_register, camera_common_regulator_get, etc.)
KBUILD_EXTRA_SYMBOLS ?= $(NVIDIA_OOT_SRC)/Module.symvers
