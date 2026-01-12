#!/bin/bash
#
# build.sh - Build IMX708 driver natively on Jetson Orin Nano
# For JetPack 6.2 (L4T R36.4.x)
#
# Usage: ./build.sh [clean|install|uninstall]
#
# NOTE: JetPack 6.2 only supports CAM1 port for IMX708!
#       Camera must be connected to CAM1, not CAM0.
#

set -e

# Default to CAM1 for JetPack 6.2
export CAM_PORT="${CAM_PORT:-CAM1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "IMX708 Camera Driver Build Script"
echo "JetPack 6.2 (L4T R36.4.x)"
echo "=========================================="
echo ""

# Check if running on Jetson
check_platform() {
    if [ ! -f /etc/nv_tegra_release ]; then
        echo_warn "This does not appear to be a Jetson device"
        echo_warn "Native build may not work correctly"
    else
        echo_info "Detected Jetson platform:"
        cat /etc/nv_tegra_release
    fi
}

# Check and install dependencies
check_dependencies() {
    echo_info "Checking dependencies..."

    local missing_deps=()

    # Check for kernel headers
    KERNEL_VER=$(uname -r)
    KERNEL_HEADERS="/lib/modules/${KERNEL_VER}/build"

    if [ ! -d "$KERNEL_HEADERS" ]; then
        echo_error "Kernel headers not found at $KERNEL_HEADERS"
        echo_info "Installing kernel headers..."
        sudo apt-get update
        sudo apt-get install -y nvidia-l4t-kernel-headers || {
            echo_error "Failed to install kernel headers"
            echo_info "Try: sudo apt install nvidia-l4t-kernel-headers"
            exit 1
        }
    fi

    # Check for NVIDIA OOT (out-of-tree) kernel headers
    # These contain tegra_v4l2_camera.h and tegracam_core.h required for camera drivers
    NVIDIA_OOT_HEADERS="/usr/src/nvidia/nvidia-oot/include/media/tegra_v4l2_camera.h"
    NVIDIA_OOT_SYMVERS="/usr/src/nvidia/nvidia-oot/Module.symvers"

    if [ ! -f "$NVIDIA_OOT_HEADERS" ]; then
        echo_warn "NVIDIA OOT headers not found at /usr/src/nvidia/nvidia-oot/"
        echo_info "Installing nvidia-l4t-kernel-oot-headers..."
        sudo apt-get update
        sudo apt-get install -y nvidia-l4t-kernel-oot-headers || {
            echo_error "Failed to install NVIDIA OOT headers"
            echo_info "Try: sudo apt install nvidia-l4t-kernel-oot-headers"
            echo_info "Or download from NVIDIA BSP sources"
            exit 1
        }
        # Verify installation
        if [ ! -f "$NVIDIA_OOT_HEADERS" ]; then
            echo_error "NVIDIA OOT headers still not found after installation"
            echo_info "Required header: media/tegra_v4l2_camera.h"
            echo_info "Expected location: /usr/src/nvidia/nvidia-oot/include/"
            echo_info ""
            echo_info "Alternative: Download NVIDIA L4T Sources and extract headers"
            echo_info "  1. Download from: https://developer.nvidia.com/embedded/jetson-linux"
            echo_info "  2. Extract public_sources.tbz2"
            echo_info "  3. Copy nvidia-oot/include to /usr/src/nvidia/nvidia-oot/"
            exit 1
        fi
    fi
    echo_info "NVIDIA OOT headers found at /usr/src/nvidia/nvidia-oot/"

    # Check for NVIDIA OOT Module.symvers (required for symbol resolution)
    # This file contains exported symbols from tegracam framework modules
    if [ ! -f "$NVIDIA_OOT_SYMVERS" ]; then
        echo_warn "NVIDIA OOT Module.symvers not found"
        echo_info "This file is required for linking against tegracam framework"
        echo_info "Attempting to install nvidia-l4t-kernel-oot-headers..."
        sudo apt-get update
        sudo apt-get install -y nvidia-l4t-kernel-oot-headers || true

        # If still missing, try to generate from installed modules
        if [ ! -f "$NVIDIA_OOT_SYMVERS" ]; then
            echo_warn "Module.symvers not provided by package"
            echo_info "Checking for pre-built NVIDIA modules..."

            # Check if nvidia modules are loaded and symvers exists elsewhere
            ALTERNATE_SYMVERS="/usr/src/nvidia/Module.symvers"
            if [ -f "$ALTERNATE_SYMVERS" ]; then
                echo_info "Found Module.symvers at $ALTERNATE_SYMVERS"
                sudo mkdir -p /usr/src/nvidia/nvidia-oot
                sudo cp "$ALTERNATE_SYMVERS" "$NVIDIA_OOT_SYMVERS"
            else
                echo_error "Module.symvers not found"
                echo_info ""
                echo_info "The Module.symvers file contains symbol exports from NVIDIA's"
                echo_info "tegracam framework (tegracam_device_register, etc.)"
                echo_info ""
                echo_info "Options to resolve:"
                echo_info "  1. Install full NVIDIA kernel source:"
                echo_info "     sudo apt install nvidia-l4t-kernel-oot-source"
                echo_info "  2. Build NVIDIA OOT modules from source to generate Module.symvers"
                echo_info "  3. Download from NVIDIA L4T BSP and extract"
                exit 1
            fi
        fi
    fi
    echo_info "NVIDIA OOT Module.symvers found"

    # Check for dtc
    if ! command -v dtc &> /dev/null; then
        missing_deps+=("device-tree-compiler")
    fi

    # Check for build-essential
    if ! command -v make &> /dev/null; then
        missing_deps+=("build-essential")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo_info "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
    fi

    echo_info "All dependencies satisfied"
}

# Build the driver
do_build() {
    echo_info "Building for camera port: $CAM_PORT"
    echo_info "Kernel version: $(uname -r)"
    echo_info "Kernel headers: /lib/modules/$(uname -r)/build"
    echo ""

    # Determine DTBO filename based on CAM_PORT
    if [ "$CAM_PORT" = "CAM1" ]; then
        DTBO_FILE="tegra234-camera-imx708-orin-nano-cam1.dtbo"
    else
        DTBO_FILE="tegra234-camera-imx708-orin-nano.dtbo"
    fi

    echo_info "Building kernel module..."
    make modules

    if [ -f "src/nv_imx708.ko" ]; then
        echo_info "Kernel module built successfully: src/nv_imx708.ko"
    else
        echo_error "Kernel module build failed"
        exit 1
    fi

    echo ""
    echo_info "Building device tree overlay..."
    make dtbo

    if [ -f "$DTBO_FILE" ]; then
        echo_info "Device tree overlay built: $DTBO_FILE"
    else
        echo_error "Device tree overlay build failed"
        exit 1
    fi

    echo ""
    echo "=========================================="
    echo_info "Build completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Install: ./build.sh install"
    echo "  2. Or run: sudo make install"
    echo "=========================================="
}

# Clean build artifacts
do_clean() {
    echo_info "Cleaning build artifacts..."
    make clean
    echo_info "Clean complete"
}

# Install the driver
do_install() {
    echo_info "Installing IMX708 driver for $CAM_PORT..."

    # Determine DTBO filename based on CAM_PORT
    if [ "$CAM_PORT" = "CAM1" ]; then
        DTBO_FILE="tegra234-camera-imx708-orin-nano-cam1.dtbo"
    else
        DTBO_FILE="tegra234-camera-imx708-orin-nano.dtbo"
    fi

    # Check if built
    if [ ! -f "src/nv_imx708.ko" ] || [ ! -f "$DTBO_FILE" ]; then
        echo_warn "Build artifacts not found, building first..."
        do_build
    fi

    make install
}

# Uninstall the driver
do_uninstall() {
    echo_info "Uninstalling IMX708 driver..."
    make uninstall
}

# Main
check_platform

case "${1:-build}" in
    build)
        check_dependencies
        do_build
        ;;
    clean)
        do_clean
        ;;
    install)
        check_dependencies
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    *)
        echo "Usage: $0 [build|clean|install|uninstall]"
        echo ""
        echo "Commands:"
        echo "  build     - Build kernel module and device tree overlay (default)"
        echo "  clean     - Remove build artifacts"
        echo "  install   - Build and install driver"
        echo "  uninstall - Remove installed driver"
        exit 1
        ;;
esac
