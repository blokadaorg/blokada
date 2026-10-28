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
# emulator process is gone for good. The report shows which, plus host memory
# over the run and any kernel OOM kills, so a dead emulator process can be told
# apart from a crash. It prints no device data: no logcat, no Appium log.
set -u

serial="${ANDROID_UDID:-emulator-5554}"
out="$(cd "$(dirname "$0")/../.." && pwd)/output"
log="$out/run-health.txt"
memlog="$out/run-health-mem.txt"
pidfile="$out/run-health.pid"

# Host memory in MB: "avail=<available> swap=<swap used>".
mem_sample() {
  free -m | awk '/^Mem:/ { a = $7 } /^Swap:/ { s = $3 } END { printf "avail=%s swap=%s", a, s }'
}

# Largest processes by resident memory, command name only.
top_rss() {
  ps -eo rss=,comm= --sort=-rss | head -n 6 | awk '{ printf "    %6d MB %s\n", $1 / 1024, $2 }'
}

case "${1:-}" in
  start)
    mkdir -p "$out"
    echo "Host memory at start (MB): $(mem_sample)"
    echo "systemd-oomd: $(systemctl is-active systemd-oomd 2>/dev/null || true)"
    free -m
    echo "  largest processes:"
    top_rss
    : >"$memlog"
    nohup sh -c "
      i=0
      while true; do
        state=\$(adb -s $serial get-state 2>/dev/null || echo offline)
        if pgrep -f '[q]emu-system' >/dev/null; then emu=running; else emu=gone; fi
        echo \"\$(date -u +%H:%M:%S) adb=\$state emulator=\$emu\"
        if [ \$((i % 5)) -eq 0 ]; then
          qemu=\$(pgrep -f '[q]emu-system' | head -n 1)
          rss=\$( [ -n \"\$qemu\" ] && ps -o rss= -p \"\$qemu\" || echo 0)
          free -m | awk -v t=\"\$(date -u +%H:%M:%S)\" -v e=\"\${rss:-0}\" '/^Mem:/ { a = \$7 } /^Swap:/ { s = \$3 } END { print t, a, s, int(e / 1024) }' >>'$memlog'
        fi
        i=\$((i + 1))
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
    if [ -s "$memlog" ]; then
      awk '
        NR == 1 || $2 < min { min = $2; mint = $1 }
        $3 > maxs { maxs = $3; maxst = $1 }
        $4 > maxe { maxe = $4 }
        END { printf "Host memory (MB, every 5 s): lowest available %s at %s, most swap used %s at %s, emulator peak RSS %s.\n", min, mint, maxs + 0, maxst ? maxst : "-", maxe + 0 }
      ' "$memlog"
      # Memory just before and after the emulator process left, if it did.
      gone="$(grep -m1 'emulator=gone' "$log" | cut -d' ' -f1)"
      if [ -n "$gone" ]; then
        echo "  around the emulator process exit at $gone (time avail swap emulator-rss):"
        awk -v g="$gone" '{ l[NR] = $0; t[NR] = $1 } END { for (i = 1; i <= NR; i++) if (t[i] >= g) { for (j = (i > 3 ? i - 3 : 1); j <= i + 1 && j <= NR; j++) print "    " l[j]; break } }' "$memlog"
      fi
    fi
    echo "  largest processes now:"
    top_rss
    # Kernel OOM killer. Hosted runners have passwordless sudo.
    # Only the trigger and victim lines: the oom-kill summary line carries cgroup
    # paths.
    oom="$(sudo -n dmesg -T 2>/dev/null | grep -E 'invoked oom-killer|Out of memory|Killed process' | sed -E 's/ (gfp_mask|order|oom_score_adj)=.*//' || true)"
    if ! sudo -n true 2>/dev/null; then
      echo "Kernel log: not readable without sudo."
    elif [ -n "$oom" ]; then
      echo "Kernel OOM killer fired:"
      echo "$oom" | sed -E 's/^/  /'
    else
      echo "Kernel log: no OOM kills."
    fi
    # systemd-oomd kills a whole cgroup on swap use or memory pressure, with no
    # kernel OOM line. Keep the reason, drop the cgroup path.
    oomd="$(sudo -n journalctl -u systemd-oomd --no-pager -o cat 2>/dev/null | grep -E 'Killed|due to' | sed -E 's#Killed /[^ ]*#Killed a cgroup#' || true)"
    if [ -n "$oomd" ]; then
      echo "systemd-oomd killed:"
      echo "$oomd" | sed -E 's/^/  /'
    else
      echo "systemd-oomd: no kills logged."
    fi
    # A fault in the emulator: the kernel's segfault/trap line, apport (Ubuntu's
    # core_pattern handler) and the emulator's own crash database. A SIGKILL
    # leaves none of these.
    faults="$(sudo -n dmesg -T 2>/dev/null | grep -E 'segfault|traps:|general protection|qemu' || true)"
    if [ -n "$faults" ]; then
      echo "Kernel log, faults:"
      echo "$faults" | sed -E 's/^/  /'
    fi
    # apport logs "called for pid N, signal S" then the executable.
    apport="$(sudo -n cat /var/log/apport.log 2>/dev/null | grep -E 'called for pid|executable:' | sed -E 's/ \(command line .*//' || true)"
    [ -n "$apport" ] && { echo "apport:"; echo "$apport" | sed -E 's/^/  /'; }
    # systemd-coredump keeps the signal and a symbolized stack. Only those: the
    # full record also names the host.
    if sudo -n coredumpctl list --no-pager >/dev/null 2>&1; then
      echo "Core dumps:"
      sudo -n coredumpctl info --no-pager 2>/dev/null \
        | grep -E '^ +(Executable|Signal):|^ +#[0-9]+ ' | head -n 40 | sed -E 's/^ +/  /'
    else
      echo "Core dumps: none."
    fi
    echo "Emulator crash database, files written during the run:"
    find /tmp/android-runner -type f -newer "$memlog" 2>/dev/null | sed -E 's#^/tmp/android-runner/#  #' | head -n 10
    ;;
  *)
    echo "usage: $0 start|report" >&2
    exit 2
    ;;
esac
