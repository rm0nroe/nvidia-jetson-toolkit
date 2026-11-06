# CLAUDE.md - AI Agent Instructions

This file provides context for AI assistants working on this repository.

## Project Overview

NVIDIA Jetson Toolkit - a resource for setting up third-party cameras on NVIDIA Jetson platforms, with working configurations for the Arducam IMX708 on Jetson Orin Nano with JetPack 6.2.

## Repository Structure

```
nvidia-jetson-toolkit/
├── README.md                           # Main documentation
├── CLAUDE.md                           # This file
├── docs/
│   ├── installation.md                 # Complete IMX708 installation guide
│   ├── ssh-setup.md                    # SSH configuration for Jetson
│   └── overlays/
│       └── imx708-nvidia-csi.dts       # Working device tree overlay
└── jp62-imx708-rpi-v3/                 # JetPack 6.2 IMX708 driver
    └── driver/
        ├── src/                        # Kernel module source
        │   ├── nv_imx708.c
        │   └── imx708_mode_tbls.h
        ├── include/
        │   └── imx708.h
        ├── dts/                        # Device tree sources
        │   ├── tegra234-camera-imx708-orin-nano.dts
        │   └── tegra234-camera-imx708-orin-nano-cam1.dts
        ├── scripts/                    # Utility and diagnostic scripts
        │   ├── validate.sh             # Post-install validation (7 tests)
        │   ├── diagnose_full.sh        # Comprehensive diagnostic (15 sections)
        │   ├── apply_overlay.sh        # Apply DTB overlay to boot partition
        │   └── fix_extlinux.sh         # Fix extlinux.conf bootloader config
        ├── build.sh                    # Build script
        └── Makefile
```

## Supported Configuration

| Component | Configuration |
|-----------|---------------|
| Camera | Arducam IMX708 12MP Wide-Angle |
| Platform | Jetson Orin Nano / Orin Nano Super |
| JetPack | 6.2 (L4T R36.4.3) |
| Driver | RidgeRun nv_imx708 v2.0.6 |
| Resolution | 4608x2592 @ 14fps |
| Format | RG10 (10-bit Bayer) |

## Key Technical Details

### Critical CSI Parameters

The breakthrough discovery: use NVIDIA's CSI parameters, not RidgeRun's defaults:

| Parameter | RidgeRun (FAILS) | NVIDIA (WORKS) |
|-----------|------------------|----------------|
| `discontinuous_clk` | `"yes"` | `"no"` |
| `lane_polarity` | `"6"` | `"0"` |
| `channel` | `channel@1` | `channel@0` |

### What Works

- Driver: `nv_imx708.ko` with `sony,imx708` compatible string
- Capture: `v4l2-ctl --stream-mmap` for raw Bayer
- Processing: Python + OpenCV with percentile normalization

### What Does NOT Work on JetPack 6.2

- `jetson-io` IMX477-C mode (capture timeouts)
- `nvarguscamerasrc` (needs ISP tuning files)
- OVERLAYS in extlinux.conf (UEFI ignores runtime overlays)

## Common Tasks

### Building the Driver

```bash
cd jp62-imx708-rpi-v3/driver
./build.sh        # Build
./build.sh install  # Install
```

### Creating Device Tree

```bash
# Compile overlay
dtc -@ -I dts -O dtb -o imx708.dtbo docs/overlays/imx708-nvidia-csi.dts

# Merge with base DTB
sudo fdtoverlay \
    -i /boot/tegra234-p3768-0000+p3767-0005-nv.dtb \
    -o /boot/tegra234-p3768-0000+p3767-0005-imx708.dtb \
    imx708.dtbo
```

### Validating Installation

```bash
# On Jetson after reboot
ls /dev/video0
v4l2-ctl -d /dev/video0 --info
dmesg | grep imx708
```

### Capturing Images

```bash
v4l2-ctl -d /dev/video0 \
    --set-fmt-video=width=4608,height=2592,pixelformat=RG10 \
    --stream-mmap --stream-count=1 \
    --stream-to=/tmp/frame.raw
```

## Code Conventions

- Shell scripts use bash with `set -e`
- Device tree files follow NVIDIA's formatting conventions
- Driver code follows Linux kernel coding style

## Important Notes

1. Camera connects to CAM1 port (not CAM0) with ribbon cable contacts facing the heatsink
2. Must use pre-merged DTB in FDT line, not OVERLAYS directive
3. Raw Bayer output needs percentile normalization for proper exposure
4. I2C address is 0x1a on bus 9

## Documentation

- [Installation Guide](docs/installation.md) - Complete setup instructions
- [SSH Setup](docs/ssh-setup.md) - Remote access configuration
- [Driver README](jp62-imx708-rpi-v3/driver/README.md) - Driver-specific docs
