#!/usr/bin/env bash
# Host and adb health around the Android emulator smoke run.
#
#   android-run-health.sh start   sample host memory and the emulator's adb
#                                 state every 5s, and keep the system log
#   android-run-health.sh report  print adb drops, memory lows and the
#                                 relevant system log lines, redacted
#
# The raw system log stays on the runner: it can hold the Private DNS
# hostname, which carries the device tag.
set -u

serial="${ANDROID_UDID:-emulator-5554}"
out="$(cd "$(dirname "$0")/../.." && pwd)/output"
log="$out/run-health.txt"
syslog="$out/logcat-run.txt"
pids="$out/run-health.pid"

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
    echo $! >"$pids"
    adb -s "$serial" logcat -c >/dev/null 2>&1 || echo "Could not clear logcat."
    nohup sh -c "while true; do adb -s $serial wait-for-device; adb -s $serial logcat -b main,system,events,crash -v threadtime; sleep 1; done" \
      >"$syslog" 2>&1 &
    echo $! >>"$pids"
    ;;
  report)
    if [ -s "$pids" ]; then
      # shellcheck disable=SC2046
      kill $(cat "$pids") 2>/dev/null || echo "A run-health sampler had already stopped."
      rm -f "$pids"
    fi
    if [ ! -s "$log" ]; then
      echo "No run-health samples."
      exit 0
    fi
    echo "Run health: $(wc -l <"$log") samples, $(grep -vc 'adb=device' "$log") with the emulator not online."
    echo "Lowest available memory: $(grep -o 'avail=[0-9]*' "$log" | cut -d= -f2 | sort -n | head -1)M"
    echo "Most swap in use: $(grep -o 'swap=[0-9]*' "$log" | cut -d= -f2 | sort -n | tail -1)M"
    grep -v 'adb=device' "$log" | head -40
    echo "System log (adb, VPN, network, process deaths, instrumentation), redacted:"
    awk '!seen[$0]++' "$syslog" 2>/dev/null \
      | grep -E ' (adbd|Vpn|VpnService|ConnectivityService|NetworkAgent|ActivityManager|AndroidRuntime|lowmemorykiller|lmkd|Watchdog|UiAutomation|Instrumentation|am_kill|am_proc_died|am_crash|am_anr|DnsResolver|PrivateDns)[ :]' \
      | grep -vE 'Start proc [0-9]+:com\.google|ActivityManager: (Changes in|Background started|Slow operation)' \
      | sed -E -e 's/[A-Za-z0-9.-]+\.blokada\.org/<host>/g' -e 's/\b[0-9a-fA-F]{16,}\b/<hex>/g' -e 's/\b[a-z]{12}\b/<id>/g' \
      | cut -c1-300 | head -300
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
