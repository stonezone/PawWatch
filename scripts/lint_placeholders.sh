#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if rg -n '^\s*\.\.\.' --glob '*.swift' "$ROOT_DIR" >/tmp/pawwatch_placeholder_hits 2>/dev/null; then
  echo 'Placeholder markers ("...") detected in Swift sources:'
  cat /tmp/pawwatch_placeholder_hits
  rm -f /tmp/pawwatch_placeholder_hits
  exit 1
fi

rm -f /tmp/pawwatch_placeholder_hits
echo "No placeholder markers found."
