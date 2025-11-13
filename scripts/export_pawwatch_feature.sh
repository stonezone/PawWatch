#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pushd "$ROOT_DIR" >/dev/null

scripts/lint_placeholders.sh >/tmp/pawwatch_lint.log
cat /tmp/pawwatch_lint.log
rm -f /tmp/pawwatch_lint.log

ZIP_PATH="$ROOT_DIR/pawWatchFeatureSources.zip"
rm -f "$ZIP_PATH"
zip -qr "$ZIP_PATH" pawWatchPackage/Sources/pawWatchFeature
echo "Exported pawWatchFeature sources to $ZIP_PATH"

popd >/dev/null
