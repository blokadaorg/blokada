#!/usr/bin/env bash
# Host and adb health around the Android emulator smoke run.
#
#   android-run-health.sh start   sample host memory and the emulator's adb
#                                 state every 5s in the background
#   android-run-health.sh report  print the samples: adb drops and memory lows
#
# When the hosted runner runs out of memory the emulator stalls, adb marks it
# offline, and UiAutomator2 reports "instrumentation process is not running".
# This shows whether that happened. Prints no device data, only states and sizes.
set -u

serial="${ANDROID_UDID:-emulator-5554}"
out="$(cd "$(dirname "$0")/../.." && pwd)/output"
log="$out/run-health.txt"

case "${1:-}" in
  start)
    mkdir -p "$out"
    nohup sh -c "
      while true; do
        state=\$(adb -s $serial get-state 2>/dev/null || echo offline)
        mem=\$(free -m | awk '/^Mem:/ {a=\$7} /^Swap:/ {s=\$3\"/\"\$2} END {print \"avail=\" a \"M swap=\" s \"M\"}')
        echo \"\$(date -u +%H:%M:%S) adb=\$state \$mem load=\$(cut -d' ' -f1 /proc/loadavg)\"
        sleep 5
      done" >"$log" 2>&1 &
    echo $! >"$out/run-health.pid"
    ;;
  report)
    if [ -s "$out/run-health.pid" ]; then
      kill "$(cat "$out/run-health.pid")" 2>/dev/null || echo "run-health sampler had already stopped."
      rm -f "$out/run-health.pid"
    fi
    if [ ! -s "$log" ]; then
      echo "No run-health samples."
      exit 0
    fi
    echo "Run health: $(wc -l <"$log") samples, $(grep -vc 'adb=device' "$log") with the emulator not online."
    echo "Lowest available memory: $(grep -o 'avail=[0-9]*' "$log" | cut -d= -f2 | sort -n | head -1)M"
    echo "Most swap in use: $(grep -o 'swap=[0-9]*' "$log" | cut -d= -f2 | sort -n | tail -1)M"
    grep -v 'adb=device' "$log" | head -40
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
