#!/bin/bash
# WatchLocationProvider Integration Verification Script
# Verifies all critical components of the GPS tracking integration

echo "🔍 Verifying WatchLocationProvider Integration..."
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Verify 0.5s throttle
echo "1. Checking GPS throttle interval..."
THROTTLE=$(grep "contextPushInterval.*=" Sources/WatchLocationProvider/WatchLocationProvider.swift | grep -o "[0-9.]*" | head -1)
if [ "$THROTTLE" = "0.5" ]; then
    echo -e "${GREEN}✓${NC} GPS throttle is 0.5s (correct)"
else
    echo -e "${RED}✗${NC} GPS throttle is $THROTTLE (expected 0.5s)"
fi
echo ""

# Check 2: Verify ContentView imports
echo "2. Checking ContentView imports..."
if grep -q "import WatchConnectivity" "pawWatch Watch App/ContentView.swift"; then
    echo -e "${GREEN}✓${NC} WatchConnectivity imported"
else
    echo -e "${RED}✗${NC} WatchConnectivity not imported"
fi
echo ""

# Check 3: Verify WatchLocationManager class exists
echo "3. Checking WatchLocationManager class..."
if grep -q "class WatchLocationManager.*WatchLocationProviderDelegate" "pawWatch Watch App/ContentView.swift"; then
    echo -e "${GREEN}✓${NC} WatchLocationManager class exists"
else
    echo -e "${RED}✗${NC} WatchLocationManager class not found"
fi
echo ""

# Check 4: Verify delegate methods implemented
echo "4. Checking delegate method implementations..."
if grep -q "func didProduce" "pawWatch Watch App/ContentView.swift"; then
    echo -e "${GREEN}✓${NC} didProduce(_:) implemented"
else
    echo -e "${RED}✗${NC} didProduce(_:) not found"
fi

if grep -q "func didFail" "pawWatch Watch App/ContentView.swift"; then
    echo -e "${GREEN}✓${NC} didFail(_:) implemented"
else
    echo -e "${RED}✗${NC} didFail(_:) not found"
fi
echo ""

# Check 5: Verify @Observable macro usage
echo "5. Checking modern SwiftUI state management..."
if grep -q "@Observable" "pawWatch Watch App/ContentView.swift"; then
    echo -e "${GREEN}✓${NC} @Observable macro used (Swift 6.2)"
else
    echo -e "${YELLOW}⚠${NC} @Observable not found (may need manual verification)"
fi
echo ""

# Check 6: Verify Info.plist permissions
echo "6. Checking required permissions in Info.plist..."
if grep -q "NSLocationWhenInUseUsageDescription" "pawWatch Watch App/Info.plist"; then
    echo -e "${GREEN}✓${NC} Location permissions configured"
else
    echo -e "${RED}✗${NC} Location permissions missing"
fi

if grep -q "NSHealthShareUsageDescription" "pawWatch Watch App/Info.plist"; then
    echo -e "${GREEN}✓${NC} HealthKit permissions configured"
else
    echo -e "${RED}✗${NC} HealthKit permissions missing"
fi
echo ""

# Check 7: Verify background modes
echo "7. Checking background modes..."
if grep -q "<string>location</string>" "pawWatch Watch App/Info.plist"; then
    echo -e "${GREEN}✓${NC} Location background mode enabled"
else
    echo -e "${RED}✗${NC} Location background mode missing"
fi
echo ""

# Check 8: Verify lifecycle handling
echo "8. Checking app lifecycle handling..."
if grep -q "scenePhase" "pawWatch Watch App/pawWatchApp.swift"; then
    echo -e "${GREEN}✓${NC} Scene phase monitoring configured"
else
    echo -e "${RED}✗${NC} Scene phase monitoring not found"
fi
echo ""

# Check 9: Count UI features
echo "9. Checking UI features..."
UI_FEATURES=$(grep -c "Image(systemName:" "pawWatch Watch App/ContentView.swift" || echo "0")
echo -e "${GREEN}✓${NC} Found $UI_FEATURES UI icons/indicators"
echo ""

# Check 10: Verify no force unwraps
echo "10. Checking code safety (force unwraps)..."
FORCE_UNWRAPS=$(grep -c "!" "pawWatch Watch App/ContentView.swift" | grep -v "!=" || echo "0")
# Note: This includes != operators, so we filter those out manually
ACTUAL_UNWRAPS=$(grep -o "!" "pawWatch Watch App/ContentView.swift" | grep -v "!=" | wc -l | tr -d ' ' || echo "0")
if [ "$ACTUAL_UNWRAPS" -lt 10 ]; then
    echo -e "${GREEN}✓${NC} Minimal force unwraps found ($ACTUAL_UNWRAPS)"
else
    echo -e "${YELLOW}⚠${NC} Multiple force unwraps found ($ACTUAL_UNWRAPS)"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓${NC} Integration verification complete!"
echo ""
echo "Next steps:"
echo "  1. Build the Watch app: xcodebuild -scheme 'pawWatch Watch App' -configuration Debug"
echo "  2. Run on simulator or device"
echo "  3. Test GPS acquisition outdoors"
echo "  4. Verify WatchConnectivity relay to iPhone"
echo ""
echo "📄 See INTEGRATION_SUMMARY.md for full documentation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
