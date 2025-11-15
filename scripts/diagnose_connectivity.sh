#!/bin/bash
#
# diagnose_connectivity.sh
# Automated WatchConnectivity troubleshooting script for pawWatch
#
# This script helps diagnose and fix common WatchConnectivity issues
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   pawWatch WatchConnectivity Diagnostic Tool              ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Step 1: Check if devices are connected
echo -e "${YELLOW}[1/5]${NC} Checking connected devices..."
echo ""

# Get list of devices
DEVICES=$(xcrun xctrace list devices 2>&1 | grep -E "iPhone|Watch" || true)

if [ -z "$DEVICES" ]; then
    echo -e "${RED}❌ No devices found!${NC}"
    echo "   Make sure your iPhone and Watch are:"
    echo "   - Connected via USB (iPhone) or WiFi"
    echo "   - Unlocked"
    echo "   - Trusted (click 'Trust' on device if prompted)"
    exit 1
fi

echo -e "${GREEN}✓ Found devices:${NC}"
echo "$DEVICES"
echo ""

# Step 2: Clean build artifacts
echo -e "${YELLOW}[2/5]${NC} Cleaning build artifacts..."
echo ""

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/pawWatch-* 2>/dev/null || true
rm -rf build_home/DerivedData/* 2>/dev/null || true

# Clean build directory
if [ -d ".build" ]; then
    rm -rf .build
fi

echo -e "${GREEN}✓ Build artifacts cleaned${NC}"
echo ""

# Step 3: Instructions for app deletion
echo -e "${YELLOW}[3/5]${NC} Manual step required: Delete existing apps"
echo ""
echo "Please delete BOTH apps from your devices:"
echo "  ${RED}→ iPhone:${NC} Long press pawWatch icon → Remove App → Delete App"
echo "  ${RED}→ Watch:${NC}  Long press pawWatch icon → Delete App"
echo ""
read -p "Press Enter after you've deleted both apps..."
echo ""

# Step 4: Build and install
echo -e "${YELLOW}[4/5]${NC} Building and installing apps..."
echo ""

echo "Building iOS app..."
xcodebuild \
    -workspace pawWatch.xcworkspace \
    -scheme pawWatch \
    -configuration Debug \
    -destination 'generic/platform=iOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "error:|warning:|succeeded" || true

echo ""
echo "Building Watch app..."
xcodebuild \
    -workspace pawWatch.xcworkspace \
    -scheme "pawWatch Watch App" \
    -configuration Debug \
    -destination 'generic/platform=watchOS' \
    clean build \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "error:|warning:|succeeded" || true

echo ""
echo -e "${GREEN}✓ Build complete${NC}"
echo ""

# Step 5: Installation instructions
echo -e "${YELLOW}[5/5]${NC} Installing apps"
echo ""
echo "Now install the apps in this specific order:"
echo ""
echo "  ${BLUE}1. Install iOS app FIRST:${NC}"
echo "     - In Xcode, select 'pawWatch' scheme"
echo "     - Select your iPhone as destination"
echo "     - Click Run (▶) or Cmd+R"
echo "     - Wait for app to launch on iPhone"
echo ""
echo "  ${BLUE}2. Then install Watch app:${NC}"
echo "     - In Xcode, select 'pawWatch Watch App' scheme"
echo "     - Select your Watch as destination"
echo "     - Click Run (▶) or Cmd+R"
echo "     - Wait for app to launch on Watch"
echo ""
read -p "Press Enter after both apps are installed and launched..."
echo ""

# Step 6: Testing instructions
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Apps Installed - Now Test Connectivity                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "To test connectivity:"
echo ""
echo "  ${BLUE}1. On iPhone:${NC}"
echo "     - Launch pawWatch app (should auto-launch)"
echo "     - Leave app in foreground"
echo ""
echo "  ${BLUE}2. On Watch:${NC}"
echo "     - Tap 'Start Tracking' button"
echo "     - Watch the 'Reachability' status"
echo ""
echo "  ${BLUE}3. Check Console Logs:${NC}"
echo "     - Xcode → Window → Devices and Simulators"
echo "     - Select iPhone → Open Console"
echo "     - Look for diagnostic report (60 '=' chars)"
echo "     - Repeat for Watch"
echo ""
echo "  ${BLUE}Expected logs:${NC}"
echo "     ${GREEN}✓ 'WCSession activated with state: 2'${NC}"
echo "     ${GREEN}✓ 'isPaired: YES'${NC}"
echo "     ${GREEN}✓ 'isCompanionAppInstalled: YES' (Watch) or 'isWatchAppInstalled: YES' (iPhone)${NC}"
echo "     ${GREEN}✓ 'isReachable: YES'${NC}"
echo ""
echo "  ${RED}If you see errors:${NC}"
echo "     ❌ 'isCompanionAppInstalled: NO' → Reinstall iOS app"
echo "     ❌ 'isWatchAppInstalled: NO' → Reinstall Watch app"
echo "     ❌ 'isReachable: NO' → Wake devices, ensure apps in foreground"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo "Diagnostic tool complete. Good luck! 🍀"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
