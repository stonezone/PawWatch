#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/surf-build-$STAMP.log"

echo "[surf_build] Writing combined build/install log to $LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

PHONE_SIM="${PHONE_SIM:-1DB950F1-CB35-414F-82FA-6026D2DC350A}"
WATCH_SIM="${WATCH_SIM:-033B2A35-8058-4413-B4F1-6A660E9E719C}"
DEST_IOS="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1"
DEST_WATCH="platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.0"
WORKSPACE="$ROOT_DIR/pawWatch.xcworkspace"
SCHEME_IOS="pawWatch"
SCHEME_WATCH="pawWatch Watch App"
DERIVED_ROOT="$HOME/Library/Developer/Xcode/DerivedData"

echo "[surf_build] Refreshing export bundle (runs placeholder lint)"
"$ROOT_DIR"/scripts/export_pawwatch_feature.sh

echo "[surf_build] Running pawWatchPackage test suite"
pushd "$ROOT_DIR/pawWatchPackage" >/dev/null
swift test
popd >/dev/null

function build_scheme() {
    local scheme="$1"
    local destination="$2"
    echo "\n[surf_build] Building $scheme for $destination"
    xcodebuild -workspace "$WORKSPACE" -scheme "$scheme" -configuration Debug -destination "$destination" build
}

function latest_derived_path() {
    ls -1dt "$DERIVED_ROOT"/pawWatch-* 2>/dev/null | head -n1
}

function product_path() {
    local derived="$1"
    local relative="$2"
    local path="$derived/$relative"
    if [[ ! -d "$path" ]]; then
        echo "[surf_build] ERROR: Missing build product at $path" >&2
        exit 1
    fi
    printf '%s' "$path"
}

function boot_sim() {
    local udid="$1"
    echo "[surf_build] Booting simulator $udid"
    xcrun simctl boot "$udid" >/dev/null 2>&1 || true
}

build_scheme "$SCHEME_IOS" "$DEST_IOS"
build_scheme "$SCHEME_WATCH" "$DEST_WATCH"

DERIVED_DIR="$(latest_derived_path)"
if [[ -z "$DERIVED_DIR" ]]; then
    echo "[surf_build] ERROR: Unable to locate DerivedData for pawWatch" >&2
    exit 1
fi

echo "[surf_build] Using DerivedData from $DERIVED_DIR"
PHONE_APP_DIR="$(product_path "$DERIVED_DIR" "Build/Products/Debug-iphonesimulator/pawWatch.app")"
WATCH_APP_DIR="$(product_path "$DERIVED_DIR" "Build/Products/Debug-watchsimulator/pawWatch Watch App.app")"

boot_sim "$PHONE_SIM"
boot_sim "$WATCH_SIM"

echo "[surf_build] Pairing $WATCH_SIM with $PHONE_SIM (if possible)"
xcrun simctl pair "$WATCH_SIM" "$PHONE_SIM" >/dev/null 2>&1 || true
echo "[surf_build] Activating pair $WATCH_SIM <> $PHONE_SIM"
xcrun simctl pairactivate "$WATCH_SIM" "$PHONE_SIM" >/dev/null 2>&1 || true

function install_and_launch() {
    local udid="$1"
    local app_path="$2"
    local bundle_id="$3"
    echo "[surf_build] Installing $bundle_id to $udid"
    xcrun simctl install "$udid" "$app_path"
    echo "[surf_build] Launching $bundle_id on $udid"
    xcrun simctl launch "$udid" "$bundle_id" || true
}

install_and_launch "$PHONE_SIM" "$PHONE_APP_DIR" "com.stonezone.pawWatch"
install_and_launch "$WATCH_SIM" "$WATCH_APP_DIR" "com.stonezone.pawWatch.watchkitapp"

echo "[surf_build] Completed successfully. Log: $LOG_FILE"
