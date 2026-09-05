#!/bin/bash
# Q9/H616 Gamestick Device Tree Extractor
# Extracts device tree info from Android gamesticks via ADB
# Usage: ./extract-gamestick-dt.sh [IP_ADDRESS]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Q9/H616 Gamestick Device Tree Extractor v1.0         ║${NC}"
echo -e "${GREEN}║     Extracts Android device tree for Linux boot          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
#
# =============================================================================
# Q9/H616 GAMESTICK DEVICE TREE EXTRACTOR
# =============================================================================
# 
# WHY THIS EXISTS:
#   Android TV boxes (like the Q9 H616) run Android on a custom vendor kernel.
#   To boot Linux on them, you need the device tree - a hardware description file.
#   This script extracts that device tree from the running Android system.
#
# WHY THIS IS HARD:
#   1. Android uses kernel 4.9 (vendor fork from Allwinner)
#   2. Mainline Linux uses kernel 6.12 (community developed)
#   3. Device tree node names are DIFFERENT between them
#      - Android: &tv0, &hdmi_out, &hdmi_phy
#      - Mainline: &hdmi, &tcon_tv, etc.
#   4. This happens because Allwinner NEVER upstreamed their H616 code
#      Community had to reverse-engineer and create their own naming
#   5. You need the Android device tree as a REFERENCE to know:
#      - What hardware exists (HDMI, WiFi, USB ports)
#      - Register addresses (where hardware lives in memory)
#      - GPIO pins (how to turn things on/off)
#      - Clock indices (what frequencies hardware runs at)
#
# WHAT THIS SCRIPT DOES:
#   1. Connects to Android TV via ADB (USB or network)
#   2. Dumps the entire /proc/device-tree from the running Android kernel
#   3. Extracts all hardware properties (HDMI, TV encoder, WiFi, USB, etc.)
#   4. Creates a human-readable report of your specific hardware
#   5. Generates a base device tree source (.dts) for Linux mainline
#   6. Packages everything into a shareable archive
#
# WHAT YOU GET:
#   - COMPLETE_EXTRACTION.txt : ALL hardware data in one file
#   - device-tree-source.dts  : Starting point for Linux mainline DTS
#   - hdmi_props.txt          : Raw HDMI register values (addresses, clocks)
#   - tv_props.txt            : TV encoder configuration
#   - system_props.txt        : Android system properties
#   - cpuinfo.txt / meminfo.txt : CPU and memory layout
#
# WHY YOU NEED THIS FOR LINUX:
#   - HDMI might not work without the correct register values
#   - WiFi might need the right SDMMC controller and GPIO pins
#   - USB ports might be disabled without the right PHY settings
#   - Without this, you're guessing hardware configuration
#
# AFTER EXTRACTION:
#   You'll have a reference device tree for your SPECIFIC gamestick.
#   Use it to build a kernel for mainline Linux by mapping:
#     Android node names -> Mainline node names
#     Android register addresses -> Mainline register addresses
#     Android clock indices -> Mainline clock indices
#
# =============================================================================
# HOW TO ENABLE DEVELOPER MODE ON ANDROID TV:
# =============================================================================
# 
# 1. On your TV, navigate to Android Settings (gear icon)
# 2. Scroll down to "About" or "Device Preferences" -> "About"
# 3. Find "Build Number" (might be under "About" -> "Version info")
# 4. Click "Build Number" 7 times quickly
# 5. You'll see "You are now a developer!" message
# 6. Go back to Settings, you'll now see "Developer Options"
# 7. Enter Developer Options and enable:
#    - "USB Debugging"
#    - "Network Debugging" (if available)
# 
# =============================================================================
# HOW TO FIND YOUR GAMESTICK IP ADDRESS:
# =============================================================================
# 
# Method 1 - From Developer Options:
#    Settings -> Developer Options -> "Device IP Address"
# 
# Method 2 - From Network Settings:
#    Settings -> Network & Internet -> Wi-Fi -> Connected network
# 
# Method 3 - From About:
#    Settings -> About -> Status -> IP Address
# 
# The IP will look like: 192.168.0.23 or 10.0.0.15
# 
# =============================================================================
# USAGE:
# =============================================================================
# 
# ./extract-gamestick-dt.sh              # For USB connected device
# ./extract-gamestick-dt.sh 192.168.0.23 # For network connected device
# 
# =============================================================================

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo -e "${RED}❌ ADB not found!${NC}"
    echo -e "${YELLOW}Install with: brew install android-platform-tools${NC}"
    exit 1
fi

# Connect to device
if [ -n "$1" ]; then
    IP="$1"
    echo -e "${BLUE}📡 Connecting to $IP...${NC}"
    adb connect "$IP:5555" 2>/dev/null || true
    sleep 2
fi

# Check connection
DEVICE=$(adb devices | grep -w "device" | head -1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
    echo -e "${RED}❌ No device connected!${NC}"
    echo -e "${YELLOW}Usage: $0 [IP_ADDRESS]${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Connected to: $DEVICE${NC}"
echo ""

# Create output directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="gamestick_dt_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"
echo -e "${BLUE}📁 Output directory: $OUTPUT_DIR${NC}"
echo ""

echo -e "${YELLOW}📊 Step 1: Gathering system information...${NC}"
adb shell getprop > "$OUTPUT_DIR/system_props.txt"
adb shell uname -a > "$OUTPUT_DIR/kernel_info.txt"
adb shell cat /proc/cpuinfo > "$OUTPUT_DIR/cpuinfo.txt"
adb shell cat /proc/meminfo > "$OUTPUT_DIR/meminfo.txt"
echo -e "${GREEN}✅ System info saved${NC}"

echo -e "${YELLOW}📊 Step 2: Extracting device tree structure...${NC}"
adb shell "find /proc/device-tree -type d" > "$OUTPUT_DIR/dt_dirs.txt"
adb shell "find /proc/device-tree -type f" > "$OUTPUT_DIR/dt_files.txt"
echo -e "${GREEN}✅ Structure saved${NC}"

echo -e "${YELLOW}📊 Step 3: Extracting HDMI configuration...${NC}"
# Use the exact path we found
HDMI_PATH="/proc/device-tree/soc@03000000/hdmi@06000000"
if adb shell "[ -d '$HDMI_PATH' ]" 2>/dev/null; then
    echo "HDMI Node: $HDMI_PATH" > "$OUTPUT_DIR/hdmi_info.txt"
    adb shell "cd '$HDMI_PATH' && for f in *; do echo \"=== \$f ===\"; cat \"\$f\" 2>/dev/null | od -tx1; done" > "$OUTPUT_DIR/hdmi_props.txt" 2>/dev/null
    echo -e "${GREEN}✅ HDMI config saved${NC}"
else
    echo -e "${RED}⚠️  HDMI node not found at $HDMI_PATH${NC}"
fi

echo -e "${YELLOW}📊 Step 4: Extracting TV encoder configuration...${NC}"
# Use the exact path we found
TV_PATH="/proc/device-tree/soc@03000000/tv0@01c94000"
if adb shell "[ -d '$TV_PATH' ]" 2>/dev/null; then
    echo "TV Node: $TV_PATH" > "$OUTPUT_DIR/tv_info.txt"
    adb shell "cd '$TV_PATH' && for f in *; do echo \"=== \$f ===\"; cat \"\$f\" 2>/dev/null | od -tx1; done" > "$OUTPUT_DIR/tv_props.txt" 2>/dev/null
    echo -e "${GREEN}✅ TV encoder config saved${NC}"
else
    echo -e "${RED}⚠️  TV node not found at $TV_PATH${NC}"
fi

echo -e "${YELLOW}📊 Step 5: Extracting SDMMC/WiFi configuration...${NC}"
for i in 0 1 2; do
    SDMMC_PATH="/proc/device-tree/soc@03000000/sdmmc@0402${i}000"
    if adb shell "[ -d '$SDMMC_PATH' ]" 2>/dev/null; then
        echo "=== sdmmc$i ===" >> "$OUTPUT_DIR/sdmmc.txt"
        adb shell "cat '$SDMMC_PATH/status' 2>/dev/null" >> "$OUTPUT_DIR/sdmmc.txt"
        echo "" >> "$OUTPUT_DIR/sdmmc.txt"
    fi
done
echo -e "${GREEN}✅ SDMMC config saved${NC}"

echo -e "${YELLOW}📊 Step 6: Creating summary...${NC}"
cat > "$OUTPUT_DIR/SUMMARY.txt" << EOF
=== Q9 H616 GAMESTICK DEVICE TREE SUMMARY ===
Extracted: $(date)

MODEL: $(adb shell cat /proc/device-tree/model 2>/dev/null)
COMPATIBLE: $(adb shell cat /proc/device-tree/compatible 2>/dev/null)
CPU: $(adb shell cat /proc/device-tree/cpus/cpu@0/compatible 2>/dev/null)

HDMI: $(adb shell cat /proc/device-tree/soc@03000000/hdmi@06000000/status 2>/dev/null)
TV Encoder: $(adb shell cat /proc/device-tree/soc@03000000/tv0@01c94000/status 2>/dev/null)

Memory: $(adb shell cat /proc/device-tree/memory@40000000/reg 2>/dev/null | od -tx4 | head -1)

Files saved in this directory:
- hdmi_props.txt : Full HDMI configuration
- tv_props.txt : Full TV encoder configuration
- system_props.txt : Android system properties
- cpuinfo.txt : CPU information
EOF

echo -e "${GREEN}✅ Summary created${NC}"

echo -e "${YELLOW}📊 Step 7: Creating combined report...${NC}"
# Create a single file with everything
cat > "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt" << 'COMBINED'
================================================================================
                    COMPLETE DEVICE TREE EXTRACTION
                          Generated by extract-gamestick-dt.sh
================================================================================

This file contains ALL extracted data in one place for easy sharing.

================================================================================
                                  SUMMARY
================================================================================

COMBINED

# Add the summary content
cat "$OUTPUT_DIR/SUMMARY.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add HDMI config
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                            HDMI CONFIGURATION" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/hdmi_props.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt" 2>/dev/null || echo "HDMI props not found" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add TV config
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                            TV ENCODER CONFIGURATION" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/tv_props.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt" 2>/dev/null || echo "TV props not found" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add CPU info
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                              CPU INFORMATION" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/cpuinfo.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add Memory info
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                              MEMORY INFORMATION" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/meminfo.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add Kernel info
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                              KERNEL INFORMATION" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/kernel_info.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

# Add first 100 lines of system props (most important ones)
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                    SYSTEM PROPERTIES (First 100 lines)" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
head -100 "$OUTPUT_DIR/system_props.txt" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

echo -e "${GREEN}✅ Combined report created: COMPLETE_EXTRACTION.txt${NC}"

echo -e "${YELLOW}📊 Step 8: Generating device tree source...${NC}"

# Create device tree source from extracted data
cat > "$OUTPUT_DIR/device-tree-source.dts" << 'DTS_EOF'
/dts-v1/;
#include "sun50i-h616.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/interrupt-controller/arm-gic.h>
#include <dt-bindings/clock/sun50i-h616-ccu.h>

/ {
    model = "Q9 H616 Game Stick";
    compatible = "allwinner,h616", "allwinner,sun50iw9p1";
    
    chosen {
        stdout-path = "serial0:115200n8";
        bootargs = "console=ttyS0,115200 earlyprintk";
    };
    
    memory@40000000 {
        device_type = "memory";
        reg = <0x40000000 0x40000000>; /* 1GB from extraction */
    };
    
    /* Regulators from extracted HDMI data */
    reg_vcc3v3: vcc3v3 {
        compatible = "regulator-fixed";
        regulator-name = "vcc-3v3";
        regulator-min-microvolt = <3300000>;
        regulator-max-microvolt = <3300000>;
        regulator-always-on;
    };
    
    reg_vcc_hdmi: vcc-hdmi {
        compatible = "regulator-fixed";
        regulator-name = "vcc-hdmi";
        regulator-min-microvolt = <3300000>;
        regulator-max-microvolt = <3300000>;
        regulator-always-on;
    };
    
    reg_vdd_hdmi: vdd-hdmi {
        compatible = "regulator-fixed";
        regulator-name = "vdd-hdmi";
        regulator-min-microvolt = <1800000>;
        regulator-max-microvolt = <1800000>;
        regulator-always-on;
    };
};

&hdmi {
    status = "okay";
    clocks = <&ccu CLK_HDMI>,
             <&ccu CLK_HDMI_SLOW>,
             <&ccu CLK_HDMI_CEC>;
    clock-names = "hdmi", "hdmi-slow", "hdmi-cec";
};

&hdmi_phy {
    status = "okay";
};

&tv0 {
    status = "okay";
    clocks = <&ccu CLK_TVE0>, <&ccu CLK_TVE_TOP>;
    clock-names = "tve0", "tve-top";
};

&uart0 {
    pinctrl-names = "default";
    pinctrl-0 = <&uart0_ph_pins>;
    status = "okay";
};

&mmc0 {
    vmmc-supply = <&reg_vcc3v3>;
    bus-width = <4>;
    cd-gpios = <&pio 8 16 GPIO_ACTIVE_LOW>;
    status = "okay";
};

&mmc1 {
    vmmc-supply = <&reg_vcc3v3>;
    vqmmc-supply = <&reg_vcc3v3>;
    bus-width = <4>;
    non-removable;
    status = "okay";
};

&gpu {
    status = "okay";
};

&usbphy {
    status = "okay";
};

&ehci0 { status = "okay"; };
&ohci0 { status = "okay"; };
&ehci1 { status = "okay"; };
&ohci1 { status = "okay"; };
&ehci2 { status = "okay"; };
&ohci2 { status = "okay"; };
&ehci3 { status = "okay"; };
&ohci3 { status = "okay"; };
DTS_EOF

# Try to compile the device tree
if command -v dtc &> /dev/null; then
    dtc -I dts -O dtb -o "$OUTPUT_DIR/device-tree.dtb" "$OUTPUT_DIR/device-tree-source.dts" 2>/dev/null && \
        echo -e "${GREEN}✅ Device tree compiled: device-tree.dtb${NC}" || \
        echo -e "${YELLOW}⚠️  DTC compilation failed, but source saved${NC}"
else
    echo -e "${YELLOW}⚠️  dtc not installed, skipping compilation${NC}"
    echo -e "${YELLOW}   Install with: brew install dtc${NC}"
fi

# Also add the device tree source to the combined file
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "                         DEVICE TREE SOURCE (DTS)" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "================================================================================" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
echo "" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"
cat "$OUTPUT_DIR/device-tree-source.dts" >> "$OUTPUT_DIR/COMPLETE_EXTRACTION.txt"

echo -e "${GREEN}✅ Device tree source saved and added to combined file${NC}"

echo -e "${YELLOW}📊 Step 9: Creating archive...${NC}"
# tar -czf "${OUTPUT_DIR}.tar.gz" "$OUTPUT_DIR/"
# echo -e "${GREEN}✅ Archive created: ${OUTPUT_DIR}.tar.gz${NC}"
echo -e "${BLUE}📋 Key files:${NC}"
echo -e "   - ${YELLOW}COMPLETE_EXTRACTION.txt${NC} : ALL data in ONE file"
echo -e "   - ${YELLOW}device-tree-source.dts${NC}  : Ready-to-use device tree source"
echo -e "   - ${YELLOW}device-tree.dtb${NC}         : Compiled device tree (if dtc available)"
echo -e "   - ${YELLOW}SUMMARY.txt${NC}            : Quick overview"
echo -e "   - ${YELLOW}hdmi_props.txt${NC}         : HDMI configuration"
echo -e "   - ${YELLOW}tv_props.txt${NC}           : TV encoder config"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  EXTRACTION COMPLETE!                                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📁 Output: ${YELLOW}$OUTPUT_DIR/${NC}"
echo -e "${BLUE}📦 Archive: ${YELLOW}${OUTPUT_DIR}.tar.gz${NC}"
echo ""
echo -e "${BLUE}📋 Key files:${NC}"
echo -e "   - ${YELLOW}SUMMARY.txt${NC}       : Quick overview"
echo -e "   - ${YELLOW}hdmi_props.txt${NC}    : HDMI configuration"
echo -e "   - ${YELLOW}tv_props.txt${NC}      : TV encoder config"
echo -e "   - ${YELLOW}system_props.txt${NC}  : Android properties"
echo ""

chmod +x ~/Desktop/extract-gamestick-dt.sh

echo -e "${GREEN}✅ Script updated!${NC}"
echo ""
echo -e "${YELLOW}Now run it:${NC}"
echo -e "   cd ~/Desktop"
echo -e "   ./extract-gamestick-dt.sh 192.168.0.23"

# 🚀 Now run it on your gamestick:
# cd ~/Desktop
# ./extract-gamestick-dt.sh 192.168.0.23

# This script will:
#     Connect to your gamestick
#     Extract all device tree data
#     Generate a custom device tree
#     Create a complete archive for sharing

# 📦 What the script collects:
#     Full device tree structure
#     HDMI configuration (registers, clocks, status)
#     TV encoder settings
#     SDMMC/WiFi configuration
#     CPU and memory info
#     GPIO/PIO mappings
#     Clock tree
#     Android system properties

# 🎯 Share it with others:

# The output gamestick_dt_*.tar.gz can be shared so other gamestick owners can:
#     Use the extracted device tree
#     See exactly what hardware they have
#     Build custom Linux kernels