# NVIDIA Jetson Camera Toolkit

A comprehensive toolkit for setting up cameras on NVIDIA Jetson platforms, with a focus on the **Arducam IMX708** on **Jetson Orin Nano Super** with **JetPack 6.2**.

## Overview

Getting third-party cameras working on Jetson can be challenging. This toolkit provides:

- **Working device tree overlays** tested on real hardware
- **Step-by-step installation guides** with troubleshooting
- **Python integration examples** for computer vision applications
- **Key learnings** from extensive debugging sessions

## Supported Configurations

| Camera | Platform | JetPack | Status |
|--------|----------|---------|--------|
| Arducam IMX708 12MP | Orin Nano Super | 6.2 (L4T R36.4.3) | ✅ Working |
| Arducam IMX708 12MP | Orin Nano | 6.2 (L4T R36.4.3) | ✅ Working |
| Arducam IMX708 12MP | Orin Nano | 6.0, 5.1.1 | See RidgeRun docs |
| Arducam IMX708 12MP | Jetson Nano | 4.6.4 | See RidgeRun docs |

## Quick Start

### IMX708 on JetPack 6.2

1. **Read the guide**: [docs/installation.md](docs/installation.md)
2. **Get the driver**: Use `NVIDIA-Jetson-IMX708-RPIV3/driver/`
3. **Apply the overlay**: Use `docs/overlays/imx708-nvidia-csi.dts`

```bash
# Quick verification after setup
ls /dev/video0
v4l2-ctl -d /dev/video0 --info
```

## Repository Structure

```
Nvidia-Jetson-Toolkit/
├── README.md                           # This file
├── CLAUDE.md                           # AI agent instructions
├── docs/
│   ├── installation.md                 # Complete IMX708 installation guide
│   ├── ssh-setup.md                    # SSH configuration guide
│   └── overlays/
│       └── imx708-nvidia-csi.dts       # Working device tree overlay
└── NVIDIA-Jetson-IMX708-RPIV3/         # RidgeRun driver source
    └── driver/                         # JetPack 6.2 kernel module
        ├── src/                        # Driver source code
        ├── include/                    # Header files
        ├── dts/                        # Device tree sources
        ├── build.sh                    # Build script
        └── validate.sh                 # Installation validation
```

## Key Findings (JetPack 6.2)

After extensive testing, we discovered several critical insights:

### What Works

| Component | Configuration |
|-----------|---------------|
| Driver | RidgeRun `nv_imx708.ko` with `sony,imx708` compatible |
| Device Tree | Custom overlay merged with `fdtoverlay` |
| Capture | `v4l2-ctl --stream-mmap` for raw Bayer |
| Processing | Python + OpenCV with percentile normalization |

### What Does NOT Work on JetPack 6.2

| Approach | Problem |
|----------|---------|
| `jetson-io` IMX477-C mode | Capture timeouts |
| `nvarguscamerasrc` | Requires missing ISP tuning files |
| OVERLAYS in extlinux.conf | UEFI boot ignores runtime overlays |
| RidgeRun's original CSI params | Wrong `discontinuous_clk` and `lane_polarity` |

### Critical CSI Parameters

The breakthrough was using NVIDIA's CSI parameters instead of RidgeRun's defaults:

| Parameter | RidgeRun (FAILS) | NVIDIA (WORKS) |
|-----------|------------------|----------------|
| `discontinuous_clk` | `"yes"` | `"no"` |
| `lane_polarity` | `"6"` | `"0"` |
| `channel` | `channel@1` | `channel@0` |

## Documentation

| Document | Description |
|----------|-------------|
| [Installation Guide](docs/installation.md) | Complete installation guide with troubleshooting |
| [SSH Setup](docs/ssh-setup.md) | Configure SSH access to Jetson |
| [Driver README](NVIDIA-Jetson-IMX708-RPIV3/driver/README.md) | Driver build and usage instructions |

## Sample Output

When everything is working correctly:

```bash
$ v4l2-ctl -d /dev/video0 --info
Driver Info:
        Driver name      : tegra-video
        Card type        : vi-output, imx708 9-001a
        Bus info         : platform:tegra-capture-vi:1

$ sudo dmesg | grep imx708
imx708 9-001a: tegracam sensor driver:imx708_v2.0.6
imx708 9-001a: detected imx708 sensor
```

## Capture Example

```python
import subprocess
import numpy as np
import cv2

# Capture raw frame
subprocess.run([
    "v4l2-ctl", "-d", "/dev/video0",
    "--set-fmt-video=width=4608,height=2592,pixelformat=RG10",
    "--stream-mmap", "--stream-count=1",
    "--stream-to=/tmp/frame.raw"
])

# Process raw Bayer to color
raw = np.fromfile("/tmp/frame.raw", dtype=np.uint16)
img = raw[:4608*2592].reshape((2592, 4608))
p2, p98 = np.percentile(img, [2, 98])
img_norm = np.clip((img.astype(float) - p2) / (p98 - p2) * 255, 0, 255).astype(np.uint8)
color = cv2.cvtColor(img_norm, cv2.COLOR_BAYER_RG2BGR)
cv2.imwrite("/tmp/capture.jpg", color)
```

## Specifications

| Parameter | Value |
|-----------|-------|
| Sensor | Sony IMX708 |
| Resolution | 4608 x 2592 (12MP) |
| Frame Rate | 14 fps (max at full resolution) |
| Pixel Format | RG10 (10-bit Bayer RGRG/GBGB) |
| Interface | CSI-2, 2 lanes |
| I2C Address | 0x1a |

## Credits

### Acknowledgments

- **[RidgeRun](https://ridgerun.com/)** - For the `nv_imx708` driver and excellent Jetson camera support
- **[NVIDIA](https://developer.nvidia.com/)** - For the Jetson platform and documentation
- **[Arducam](https://www.arducam.com/)** - For the IMX708 camera module

### Contributors

- Documentation and testing by the AI Companion project team

### License

- RidgeRun driver: GPL v2
- Documentation: MIT

## Contributing

Found an issue or have improvements?

1. **Open an issue** on this repository
2. **Submit a pull request** with your changes
3. **Share your experiences** on the [NVIDIA Developer Forums](https://forums.developer.nvidia.com/)

## Related Projects

- [RidgeRun IMX708 Driver](https://github.com/RidgeRun/NVIDIA-Jetson-IMX708-RPIV3) - Original driver source

---

**Last Updated**: December 24, 2025
**Tested On**: Jetson Orin Nano Super 8GB, JetPack 6.2, Arducam IMX708
