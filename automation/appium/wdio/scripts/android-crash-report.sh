#!/usr/bin/env bash
# Emulator-side diagnostics for the Android smoke run.
#
#   android-crash-report.sh start   capture logcat (all buffers, across adb
#                                   drops) and host load into automation/appium/output
#   android-crash-report.sh report  print only the lines that explain an
#                                   instrumentation / adb drop, redacted
#
# The raw files stay on the runner: logcat and the Appium log can hold the
# Private DNS hostname, which carries the device tag. The report redacts
# hostnames, long hex tokens and 12-letter ids, and skips the app's own lines.
set -u

serial="${ANDROID_UDID:-emulator-5554}"
out="$(cd "$(dirname "$0")/../.." && pwd)/output"
mkdir -p "$out"

redact() {
  sed -E \
    -e 's/[A-Za-z0-9.-]+\.blokada\.org/<host>/g' \
    -e 's/\b[0-9a-fA-F]{16,}\b/<hex>/g' \
    -e 's/\b[a-z]{12}\b/<id>/g' \
    | cut -c1-400
}

case "${1:-}" in
  start)
    adb -s "$serial" logcat -G 16M >/dev/null 2>&1 || true
    nohup sh -c "while true; do adb -s $serial wait-for-device; echo \"--- logcat attach \$(date -u +%FT%TZ)\"; adb -s $serial logcat -b all -v threadtime -v UTC; sleep 1; done" \
      >"$out/logcat-all.txt" 2>&1 &
    nohup sh -c 'while true; do echo "--- $(date -u +%FT%TZ)"; uptime; free -m | sed -n 2,3p; sleep 10; done' \
      >"$out/host-load.txt" 2>&1 &
    adb -s "$serial" shell cat /proc/uptime >"$out/guest-uptime-start.txt" 2>&1 || true
    ;;
  report)
    echo "== guest uptime at start / now (a reset means the guest rebooted)"
    cat "$out/guest-uptime-start.txt" 2>/dev/null
    adb -s "$serial" shell cat /proc/uptime 2>&1 || true
    echo "== guest memory now"
    adb -s "$serial" shell cat /proc/meminfo 2>&1 | sed -n 1,6p || true
    echo "== logcat attaches (more than one means adb lost the device)"
    grep -- '--- logcat attach' "$out/logcat-all.txt" 2>/dev/null
    echo "== logcat: crashes, kills, watchdog, instrumentation"
    grep -E 'AndroidRuntime|FATAL|lowmemorykiller|lmkd|Process .* has died|am_proc_died|am_kill|am_low_memory|Watchdog|WATCHDOG|system_server|Kernel panic|uiautomator|UiAutomator|Instrumentation|instrumentation|adbd|ActivityManager: (Start proc|Killing|Process)|Low on memory|kswapd|oom' \
      "$out/logcat-all.txt" 2>/dev/null \
      | grep -vE ' (flutter|org\.blokada|blokada)[ :]' \
      | redact | head -400
    echo "== Appium server: adb and instrumentation errors"
    grep -E 'instrumentation|Instrumentation|UiAutomator2 server|device offline|not found|exited with code|ECONNRESET|socket hang up|uiautomator2.*(crash|died|start)' \
      "$out/appium-android-server.log" 2>/dev/null \
      | redact | head -200
    echo "== host load (every 10s)"
    cat "$out/host-load.txt" 2>/dev/null | tail -120
    echo "== host kernel OOM"
    sudo dmesg 2>/dev/null | grep -iE 'oom|killed process' | tail -20 || true
    pkill -f 'logcat -b all' || true
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
