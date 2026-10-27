#!/usr/bin/env bash
# Emulator link health around the Android smoke run on CI.
#
#   android-run-health.sh start   sample the emulator's adb state and whether
#                                 its process is alive, once a second
#   android-run-health.sh report  print when the emulator dropped off adb
#
# "instrumentation process is not running" from UiAutomator2 means adb lost the
# emulator: the host adb server logs "connection terminated" and the run loses
# the spec in flight. Usually the link is back in seconds; sometimes the
# emulator process is gone for good. The report shows which, and prints no
# device data.
set -u

serial="${ANDROID_UDID:-emulator-5554}"
out="$(cd "$(dirname "$0")/../.." && pwd)/output"
log="$out/run-health.txt"
pidfile="$out/run-health.pid"

case "${1:-}" in
  start)
    mkdir -p "$out"
    nohup sh -c "
      while true; do
        state=\$(adb -s $serial get-state 2>/dev/null || echo offline)
        if pgrep -f '[q]emu-system' >/dev/null; then emu=running; else emu=gone; fi
        echo \"\$(date -u +%H:%M:%S) adb=\$state emulator=\$emu\"
        sleep 1
      done" >"$log" 2>&1 &
    echo $! >"$pidfile"
    ;;
  report)
    if [ -s "$pidfile" ]; then
      kill "$(cat "$pidfile")" 2>/dev/null || echo "The run-health sampler had already stopped."
      rm -f "$pidfile"
    fi
    if [ ! -s "$log" ]; then
      echo "No run-health samples."
      exit 0
    fi
    echo "Emulator link: $(wc -l <"$log") samples, $(grep -vc 'adb=device' "$log") with the emulator off adb."
    # First and last sample of each stretch off adb.
    awk '
      /adb=device/ { if (off) print "  off adb " first " .. " last " (" state ")"; off = 0; next }
      { if (!off) first = $1; off = 1; last = $1; state = $3 }
      END { if (off) print "  off adb " first " .. " last " (" state ", until the end)" }
    ' "$log"
    for f in /tmp/adb.*.log; do
      [ -f "$f" ] && grep -h 'connection terminated' "$f" | sed -E 's/^([0-9-]+ [0-9:.]+) .* (emulator-[0-9]+: connection terminated.*)$/  host adb \1: \2/' | sort -u
    done
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
