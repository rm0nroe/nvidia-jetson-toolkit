#!/bin/bash
# Apply IMX708 device tree overlay to boot DTB
# This script merges the overlay directly since JetPack 6.2 doesn't process OVERLAYS directive
#
# NOTE: JetPack 6.2 loads DTB from /boot/ (NOT /boot/dtb/) - we update BOTH to be safe

# Don't use set -e so we can process all locations even if one fails

DTB_NAME="kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb"
OVERLAY="/boot/tegra234-camera-imx708-orin-nano.dtbo"

# Both possible DTB locations - /boot/ FIRST (that's what bootloader uses!)
DTB_LOCATIONS=(
    "/boot/${DTB_NAME}"
    "/boot/dtb/${DTB_NAME}"
)

SUCCESS_COUNT=0

echo "=== IMX708 Device Tree Overlay Application ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run with sudo"
    exit 1
fi

# Check overlay exists
if [ ! -f "$OVERLAY" ]; then
    echo "ERROR: Overlay not found at $OVERLAY"
    echo "Run './build.sh install' first"
    exit 1
fi

echo "Overlay: $OVERLAY ($(stat -c%s "$OVERLAY") bytes)"
echo ""

# Process each DTB location
for DTB_PATH in "${DTB_LOCATIONS[@]}"; do
    echo "----------------------------------------"
    echo "Checking: $DTB_PATH"

    if [ ! -f "$DTB_PATH" ]; then
        echo "  SKIP: File not found"
        echo ""
        continue
    fi

    BEFORE_SIZE=$(stat -c%s "$DTB_PATH")
    echo "  Found: $BEFORE_SIZE bytes"

    DTB_BACKUP="${DTB_PATH}.backup"

    # Create backup if it doesn't exist
    if [ ! -f "$DTB_BACKUP" ]; then
        echo "  Creating backup..."
        if cp "$DTB_PATH" "$DTB_BACKUP"; then
            echo "  Backup created: $DTB_BACKUP"
        else
            echo "  ERROR: Failed to create backup"
            echo ""
            continue
        fi
    else
        BACKUP_SIZE=$(stat -c%s "$DTB_BACKUP")
        echo "  Backup exists: $DTB_BACKUP ($BACKUP_SIZE bytes)"
    fi

    # Merge overlay into DTB
    echo "  Applying overlay..."
    if fdtoverlay -i "$DTB_BACKUP" -o "$DTB_PATH" "$OVERLAY" 2>&1; then
        AFTER_SIZE=$(stat -c%s "$DTB_PATH")
        echo "  SUCCESS: Overlay applied"
        echo "  Size: $BEFORE_SIZE -> $AFTER_SIZE bytes"

        # Verify merge
        if command -v dtc &> /dev/null; then
            if dtc -I dtb -O dts "$DTB_PATH" 2>/dev/null | grep -q "imx708"; then
                echo "  VERIFIED: imx708 node found in DTB"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "  WARNING: imx708 not found in verification"
            fi
        else
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    else
        echo "  ERROR: fdtoverlay failed"
        echo "  Restoring backup..."
        cp "$DTB_BACKUP" "$DTB_PATH"
    fi
    echo ""
done

echo "========================================"
echo ""
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo "SUCCESS: Applied overlay to $SUCCESS_COUNT DTB location(s)"
    echo ""
    echo "Reboot required for changes to take effect."
    read -p "Reboot now? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Rebooting..."
        reboot
    else
        echo "Run 'sudo reboot' when ready."
    fi
else
    echo "ERROR: Failed to apply overlay to any DTB location!"
    exit 1
fi
