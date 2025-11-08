#!/usr/bin/env bash
set -euo pipefail

git_root=$(git rev-parse --show-toplevel)
cd "$git_root"

git config core.hooksPath githooks

cat <<MSG
Git hooks path updated to: $(git config core.hooksPath)
The version enforcement hook will now run on every commit.
MSG
