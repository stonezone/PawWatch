#!/usr/bin/env bash
set -euo pipefail

if [[ "${SKIP_VERSION_CHECK:-0}" == "1" ]]; then
  exit 0
fi

VERSION_FILE="Config/version.json"
PBX_FILE="pawWatch.xcodeproj/project.pbxproj"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[version-check] Missing $VERSION_FILE" >&2
  exit 1
fi

staged_files=$(git diff --cached --name-only || true)
if [[ -z "$staged_files" ]]; then
  exit 0
fi

has_non_version_changes=$(printf '%s
' "$staged_files" | grep -v -x "$VERSION_FILE" || true)
version_staged=$(printf '%s
' "$staged_files" | grep -x "$VERSION_FILE" || true)

if [[ -n "$has_non_version_changes" && -z "$version_staged" ]]; then
  echo "[version-check] Config/version.json must be staged whenever other files are committed." >&2
  echo "Run scripts/bump_version.py to generate a new 1.0.x release number." >&2
  exit 1
fi

current_version=$(python3 - <<'PY'
import json, pathlib
path = pathlib.Path("Config/version.json")
data = json.loads(path.read_text())
print(f"{data['major']}.{data['minor']}.{data['patch']}")
PY
)

if ! grep -q "MARKETING_VERSION = ${current_version};" "$PBX_FILE"; then
  echo "[version-check] project.pbxproj is not using marketing version ${current_version}." >&2
  echo "Run scripts/bump_version.py to sync the project file." >&2
  exit 1
fi

exit 0
