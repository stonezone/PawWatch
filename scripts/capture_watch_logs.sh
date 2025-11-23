#!/bin/bash
set -euo pipefail
BUNDLE="com.stonezone.pawWatch.watchkitapp"
DURATION="5m"
log show --last "$DURATION" --predicate "subsystem CONTAINS 'pawwatch' || process == 'pawWatch Watch App' || process CONTAINS 'pawWatch'" --style compact
