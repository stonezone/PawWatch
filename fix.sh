#!/bin/bash

# pawWatch WatchConnectivity Diagnostic & Fix Script
# Fixes asymmetrical pairing where watch sees phone but phone doesn't see watch

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCODE_PROJECT="$PROJECT_ROOT/pawWatch.xcworkspace"
PHONE_TARGET="pawWatch"
WATCH_TARGET="pawWatch Watch App"

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║        pawWatch WatchConnectivity Diagnostic & Repair             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check project structure
echo "🔍 Step 1: Verifying project structure..."
if [ ! -f "$PROJECT_ROOT/Config/Shared.xcconfig" ]; then
    echo "❌ ERROR: Shared.xcconfig not found"
    exit 1
fi

BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "$PROJECT_ROOT/Config/Shared.xcconfig" | grep -o "com\.stonezone\.[a-zA-Z]*" | head -1)
TEAM_ID=$(grep "DEVELOPMENT_TEAM" "$PROJECT_ROOT/Config/Shared.xcconfig" | grep -o "[A-Z0-9]\{10\}")

echo "   ✅ Bundle ID: $BUNDLE_ID"
echo "   ✅ Team ID: $TEAM_ID"
echo ""

# Check entitlements
echo "🔍 Step 2: Verifying entitlements..."
if ! grep -q "group.com.stonezone.pawWatch" "$PROJECT_ROOT/Config/pawWatch.entitlements"; then
    echo "❌ ERROR: App Group entitlement missing from phone app"
    exit 1
fi
if ! grep -q "group.com.stonezone.pawWatch" "$PROJECT_ROOT/Config/pawWatch_Watch_App.entitlements"; then
    echo "❌ ERROR: App Group entitlement missing from watch app"
    exit 1
fi
echo "   ✅ Both apps have App Group entitlement"
echo ""

# Check WCSession setup
echo "🔍 Step 3: Checking WatchConnectivity setup..."
if grep -q "WCSession.default" "$PROJECT_ROOT/pawWatch/PhoneWatchConnectivityManager.swift"; then
    echo "   ✅ Phone app: WCSession initialized"
else
    echo "   ❌ Phone app: WCSession NOT initialized"
fi

if grep -q "wcSession.activate()" "$PROJECT_ROOT/pawWatchPackage/Sources/pawWatchFeature/WatchLocationProvider.swift"; then
    echo "   ✅ Watch app: WCSession activated"
else
    echo "   ❌ Watch app: WCSession NOT activated"
fi
echo ""

# Check watch companion ID
echo "🔍 Step 4: Checking watch companion configuration..."
COMPANION_ID=$(grep -A1 "WKCompanionAppBundleIdentifier" "$PROJECT_ROOT/pawWatch Watch App/Info.plist" | grep -o "com\.stonezone\.[a-zA-Z]*" | head -1)
echo "   Companion app ID: $COMPANION_ID"
if [ "$COMPANION_ID" = "$BUNDLE_ID" ]; then
    echo "   ✅ Watch knows about phone app"
else
    echo "   ⚠️  Watch companion ID mismatch (watch: $COMPANION_ID, phone: $BUNDLE_ID)"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Build instructions
echo "📋 REQUIRED: Build Order (CRITICAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Open Xcode:"
echo "   open '$XCODE_PROJECT'"
echo ""
echo "1️⃣  BUILD WATCH APP FIRST:"
echo "   • Scheme → Select '$WATCH_TARGET'"
echo "   • Select Apple Watch simulator/device"
echo "   • Product → Clean Build Folder (Shift+Cmd+K)"
echo "   • Product → Build (Cmd+B)"
echo "   • Product → Run (Cmd+R)"
echo "     ✅ Wait for watch app to launch on simulator"
echo ""
echo "2️⃣  THEN BUILD PHONE APP:"
echo "   • Scheme → Select '$PHONE_TARGET'"
echo "   • Select iPhone simulator/device"
echo "   • Product → Clean Build Folder (Shift+Cmd+K)"
echo "   • Product → Build (Cmd+B)"
echo "   • Product → Run (Cmd+R)"
echo "     ✅ Wait for iPhone app to launch"
echo ""
echo "3️⃣  START TRACKING:"
echo "   • On Watch: Tap 'Start Tracking'"
echo "   • On iPhone: Open app and check connection status"
echo "   • Verify: Connection shows 'iPhone Connected'"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Verification checks
echo "✅ Verification Checklist:"
echo ""
echo "  PHONE SIDE (iPhone):"
echo "  □ PhoneWatchConnectivityManager initializes"
echo "  □ WCSession.activate() called in main app"
echo "  □ Delegates set before activation"
echo "  □ Connection status shows 'iPhone Connected' (not 'Inactive')"
echo ""
echo "  WATCH SIDE (Apple Watch):"
echo "  □ WatchLocationManager creates WatchLocationProvider"
echo "  □ startTracking() calls startWorkoutAndStreaming()"
echo "  □ configureWatchConnectivity() calls WCSession.activate()"
echo "  □ Session activation sends diagnostic to phone"
echo ""
echo "  COMMON FIXES IF STILL NOT WORKING:"
echo "  □ Delete both apps from simulators/devices"
echo "  □ XCode → Product → Clean Build Folder"
echo "  □ Rebuild watch app FIRST, then phone app"
echo "  □ Check Xcode console logs for WCSession errors"
echo "  □ Verify both have same Team ID: $TEAM_ID"
echo "  □ Verify both have App Group: group.com.stonezone.pawWatch"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo ""

echo "✨ Next: Open Xcode and follow the build order above"
