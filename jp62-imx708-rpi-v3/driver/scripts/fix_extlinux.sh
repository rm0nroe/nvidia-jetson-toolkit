#!/bin/bash
# Fix extlinux.conf to use our modified DTB with camera overlay

EXTLINUX="/boot/extlinux/extlinux.conf"
DTB="/boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb"

echo "=== Fix extlinux.conf ==="
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run with sudo"
    exit 1
fi

# Check DTB exists
if [ ! -f "$DTB" ]; then
    echo "ERROR: DTB not found: $DTB"
    exit 1
fi

# Backup extlinux.conf
if [ ! -f "${EXTLINUX}.backup" ]; then
    echo "Creating backup of extlinux.conf..."
    cp "$EXTLINUX" "${EXTLINUX}.backup"
    echo "Backup: ${EXTLINUX}.backup"
fi

# Check if FDT line already exists
if grep -q "^[[:space:]]*FDT " "$EXTLINUX"; then
    echo "FDT line already exists in extlinux.conf"
    grep "FDT" "$EXTLINUX"
else
    echo "Adding FDT line to extlinux.conf..."

    # Add FDT line after INITRD line
    sed -i '/INITRD/a\      FDT /boot/kernel_tegra234-p3768-0000+p3767-0005-nv-super.dtb' "$EXTLINUX"

    echo "FDT line added!"
fi

echo ""
echo "Current extlinux.conf:"
echo "----------------------------------------"
cat "$EXTLINUX"
echo "----------------------------------------"

echo ""
echo "Verify DTB has imx708:"
if dtc -I dtb -O dts "$DTB" 2>/dev/null | grep -q "imx708"; then
    echo "  ✓ imx708 found in DTB"
else
    echo "  ✗ imx708 NOT in DTB - run apply_overlay.sh first!"
    exit 1
fi

echo ""
echo "=== Done ==="
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
