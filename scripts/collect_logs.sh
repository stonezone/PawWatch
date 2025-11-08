#!/usr/bin/env bash
#
# pawWatch log collector
# ----------------------
# Captures OSLog output for the pawWatch subsystem (`com.stonezone.pawwatch`).
# Tips:
#  * iPhone: plug in, open Console.app, select the device once so macOS trusts it,
#    then this script can read `log stream` locally.
#  * Apple Watch: ensure the watch is paired+trusted and visible inside Console.app
#    (Window ▸ Devices and Simulators). With the watch selected, this same
#    predicate streams watchOS events as they mirror through the phone.
#
# Usage examples:
#   scripts/collect_logs.sh --duration 10 --out logs/wc-session.jsonl
#   scripts/collect_logs.sh   # streaming to stdout until Ctrl+C

set -euo pipefail

print_help() {
  cat <<'USAGE'
Usage: collect_logs.sh [options]

Options:
  --duration <minutes>   Stop after N minutes (default: run until Ctrl+C)
  --out <file>           Write logs to the given file.
                         Defaults to logs/pawwatch-YYYYmmdd-HHMMSS.jsonl
  -h, --help             Show this help and exit

The script wraps `log stream --style json --predicate 'subsystem == "com.stonezone.pawwatch"'`
so you can archive identical traces on both iPhone and paired Watch sessions.
USAGE
}

duration_min=""
out_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      [[ $# -lt 2 ]] && { echo "--duration requires a value" >&2; exit 1; }
      duration_min="$2"
      shift 2
      ;;
    --out)
      [[ $# -lt 2 ]] && { echo "--out requires a value" >&2; exit 1; }
      out_path="$2"
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      print_help >&2
      exit 1
      ;;
  esac
done

duration_sec=""
if [[ -n "$duration_min" ]]; then
  if ! [[ "$duration_min" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "--duration expects a numeric value (minutes)" >&2
    exit 1
  fi
  duration_sec=$(python3 - <<'PY'
import sys
val = float(sys.argv[1])
print(int(val * 60))
PY
"$duration_min")
fi

timestamp() {
  date +%Y%m%d-%H%M%S
}

if [[ -z "$out_path" ]]; then
  mkdir -p logs
  out_path="logs/pawwatch-$(timestamp).jsonl"
fi

if [[ -n "$out_path" ]]; then
  mkdir -p "$(dirname "$out_path")"
fi

predicate='subsystem == "com.stonezone.pawwatch"'
log_cmd=(log stream --style json --predicate "$predicate")

echo "[collect_logs] Writing to $out_path"

cleanup() {
  if [[ -n ${log_pid:-} ]]; then
    kill "$log_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -n "$duration_sec" ]]; then
  # Run log stream in background and stop after duration
  "${log_cmd[@]}" >"$out_path" &
  log_pid=$!
  ( sleep "$duration_sec" && kill "$log_pid" >/dev/null 2>&1 ) &
  waiter=$!
  wait "$log_pid" 2>/dev/null || true
  wait "$waiter" 2>/dev/null || true
else
  "${log_cmd[@]}" >"$out_path"
fi

echo "[collect_logs] Done"
