#!/bin/bash
# Full diagnostic for IMX708 camera detection issues

echo "=============================================="
echo "IMX708 Camera Full Diagnostic"
echo "=============================================="
echo ""

echo "=== 1. SYSTEM INFO ==="
cat /etc/nv_tegra_release 2>/dev/null || echo "Not a Tegra system?"
uname -r
echo ""

echo "=== 2. I2C BUS SCAN (ALL BUSES) ==="
for bus in 0 1 2 3 4 5 6 7 8 9 10; do
    if [ -e "/dev/i2c-$bus" ]; then
        echo "--- Bus $bus ---"
        sudo i2cdetect -y -r $bus 2>/dev/null
        echo ""
    fi
done

echo "=== 3. I2C ADAPTERS ==="
ls -la /sys/bus/i2c/devices/ 2>/dev/null
echo ""
for i in /sys/bus/i2c/devices/i2c-*/; do
    if [ -d "$i" ]; then
        bus=$(basename "$i")
        name=$(cat "${i}name" 2>/dev/null)
        echo "  $bus: $name"
    fi
done
echo ""

echo "=== 4. CAMERA DEVICE TREE NODES ==="
echo "Looking for camera-related nodes..."
ls -la /sys/firmware/devicetree/base/ | grep -iE "cam|csi|vi|imx"
echo ""
echo "tegra-camera-platform:"
ls /sys/firmware/devicetree/base/tegra-camera-platform/ 2>/dev/null || echo "  Not found"
echo ""

echo "=== 5. IMX708 DEVICE NODE ==="
if [ -d "/sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a" ]; then
    echo "✓ IMX708 node EXISTS at /bus@0/i2c@3180000/rbpcv3_imx708_a@1a"
    ls /sys/firmware/devicetree/base/bus@0/i2c@3180000/rbpcv3_imx708_a@1a/
else
    echo "✗ IMX708 node NOT FOUND in device tree"
fi
echo ""

echo "=== 6. KERNEL MODULE STATUS ==="
if lsmod | grep -q nv_imx708; then
    echo "✓ nv_imx708 module is LOADED"
    lsmod | grep imx708
else
    echo "✗ nv_imx708 module NOT loaded"
    echo "  Trying to load..."
    sudo modprobe nv_imx708 2>&1
fi
echo ""

echo "=== 7. VIDEO DEVICES ==="
ls -la /dev/video* 2>/dev/null || echo "No /dev/video* devices found"
echo ""

echo "=== 8. DMESG - I2C ERRORS ==="
sudo dmesg | grep -iE "i2c.*error|i2c.*fail|i2c.*timeout|3180000.*error" | tail -15
echo ""

echo "=== 9. DMESG - IMX708 ==="
sudo dmesg | grep -i imx708 | tail -20
echo ""

echo "=== 10. DMESG - CSI/CAMERA ==="
sudo dmesg | grep -iE "csi|nvcsi|tegra-capture|camera" | tail -15
echo ""

echo "=== 11. GPIO STATUS FOR CAMERA ==="
echo "Looking for camera-related GPIOs..."
sudo cat /sys/kernel/debug/gpio 2>/dev/null | grep -iE "cam|reset|H6|CAM" | head -10 || echo "  Cannot read GPIO debug"
echo ""

echo "=== 12. POWER/REGULATOR STATUS ==="
echo "Camera-related regulators:"
if [ -d /sys/class/regulator ]; then
    for reg in /sys/class/regulator/regulator.*/; do
        name=$(cat "${reg}name" 2>/dev/null)
        state=$(cat "${reg}state" 2>/dev/null)
        if echo "$name" | grep -qiE "cam|avdd|dvdd|iovdd|vana|vdig"; then
            echo "  $name: $state"
        fi
    done
fi
echo ""

echo "=== 13. CSI PORT STATUS ==="
ls /sys/firmware/devicetree/base/bus@0/host1x@13e00000/nvcsi@15a00000/ 2>/dev/null | head -20
echo ""

echo "=== 14. MEDIA DEVICES ==="
ls -la /dev/media* 2>/dev/null || echo "No /dev/media* devices"
if [ -e /dev/media0 ]; then
    echo ""
    echo "Media device info:"
    media-ctl -d /dev/media0 -p 2>/dev/null | head -30
fi
echo ""

echo "=== 15. I2C BUS 2 DETAILED CHECK ==="
echo "Checking i2c-2 (3180000.i2c) specifically..."
if [ -e /dev/i2c-2 ]; then
    echo "  /dev/i2c-2 exists"
    echo "  Scanning with repeated start..."
    sudo i2cdetect -y -r 2
    echo ""
    echo "  Trying direct read at 0x1a..."
    sudo i2cget -y 2 0x1a 0x00 2>&1 || echo "  (Read failed - camera not responding)"
else
    echo "  /dev/i2c-2 does NOT exist!"
fi
echo ""

echo "=============================================="
echo "DIAGNOSTIC COMPLETE"
echo "=============================================="
echo ""
echo "INTERPRETATION:"
echo "- If I2C bus 2 shows '1a': Camera IS detected, driver issue"
echo "- If I2C bus 2 is empty: Camera NOT detected, hardware issue"
echo "- Check dmesg sections for specific error messages"
echo ""
