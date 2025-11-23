#!/bin/bash
# Script to capture console logs from Apple Watch
# Usage: ./capture_watch_logs.sh [output_file]

OUTPUT_FILE="${1:-watch_logs.txt}"

echo "🔍 Capturing Apple Watch console logs..."
echo "📝 Output will be saved to: $OUTPUT_FILE"
echo ""
echo "Looking for connected Apple Watch devices..."

# List available devices
xcrun devicectl list devices 2>&1 | grep -i "watch"

echo ""
echo "To capture logs, run this command manually:"
echo "  xcrun devicectl device monitor logs --device <WATCH_UDID> --style compact > $OUTPUT_FILE"
echo ""
echo "Or to stream logs in real-time:"
echo "  xcrun devicectl device monitor logs --device <WATCH_UDID> --style compact"
echo ""
echo "Alternative using older tools:"
echo "  xcrun simctl logverbose <WATCH_UDID> enable"
echo "  log stream --device --predicate 'process == \"pawWatch\"' > $OUTPUT_FILE"
