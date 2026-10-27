#!/usr/bin/env bash
# Host and adb health around the Android emulator smoke run.
#
#   android-run-health.sh start   sample host memory and the emulator's adb
#                                 state every second, and keep the system log
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

redact() {
  sed -E -e 's/[A-Za-z0-9.-]+\.blokada\.org/<host>/g' -e 's/\b[0-9a-fA-F]{16,}\b/<hex>/g' \
    -e 's/\b[a-z]{12}\b/<id>/g' | cut -c1-300
}

case "${1:-}" in
  start)
    mkdir -p "$out"
    nohup sh -c "
      while true; do
        state=\$(adb -s $serial get-state 2>/dev/null || echo offline)
        mem=\$(free -m | awk '/^Mem:/ {a=\$7} /^Swap:/ {s=\$3\"/\"\$2} END {print \"avail=\" a \"M swap=\" s \"M\"}')
        echo \"\$(date -u +%H:%M:%S) adb=\$state \$mem load=\$(cut -d' ' -f1 /proc/loadavg)\"
        sleep 1
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
    echo "System log: adbd and TCP socket teardown over the whole run, redacted:"
    awk '!seen[$0]++' "$syslog" 2>/dev/null \
      | grep -E ' adbd *:|InetDiagMessage: Destroyed [1-9]|Destroyed live tcp sockets|ConnectivityService: .*(VPN|Vpn|LOST|lost|DISCONNECTED|PrivateDns|private DNS)' \
      | grep -vE 'jdwp connection|failed to connect to socket .tcp:6790' \
      | redact | tail -150
    echo "Host adb server log (why it dropped the emulator):"
    for f in /tmp/adb.*.log "${TMPDIR:-/tmp}"/adb.*.log; do
      [ -f "$f" ] && grep -viE 'jdwp|track-devices' "$f" | redact | tail -60
    done
    # Everything the system logged just before the emulator first went offline.
    # Anchor: the first UiAutomator2/adb failure WebdriverIO saw, else the
    # first offline sample.
    first=$(grep -E 'instrumentation process is not running|exited with code 255|socket hang up|device offline' \
      "$out/wdio-run.txt" 2>/dev/null | grep -oE 'T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+Z' | head -1 | cut -c2-9)
    [ -n "$first" ] || first=$(grep -v 'adb=device' "$log" | head -1 | cut -d' ' -f1)
    if [ -n "$first" ]; then
      echo "System log from 10s before the first adb/instrumentation failure ($first), redacted:"
      awk -v t="$first" '
        function secs(s) { split(s, p, ":"); return p[1] * 3600 + p[2] * 60 + p[3] }
        !seen[$0]++ && $2 ~ /^[0-9]+:[0-9]+:[0-9]+/ {
          d = secs(substr($2, 1, 8)) - secs(t)
          if (d >= -10 && d <= 3) print
        }' "$syslog" \
        | grep -E ' (adbd|init|kernel|lowmemorykiller|lmkd|ActivityManager|am_[a-z_]+|AndroidRuntime|Watchdog|UiAutomation|TestRunner|appium|InetDiagMessage|ConnectivityService|Vpn|DnsResolver|resolv|system_server|binder|ziparchive|libc|tombstoned|DEBUG|crash_dump64) *:' \
        | grep -vE ' I appium  :|hiddenapi|AssetManager2|AppsFilter|freezing|unfroze|NetReassign|resolv  : (res_|doQuery|resolv_cache|GetAddrInfo)' \
        | redact | head -400
    fi
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
