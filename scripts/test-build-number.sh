#!/usr/bin/env bash
# Exercises the allocator against a throwaway local "remote".
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")" && pwd)/build-number.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git init --quiet --bare "$tmp/remote.git"
git init --quiet "$tmp/work"
cd "$tmp/work"
git config user.email t@example.com
git config user.name Test
git remote add origin "$tmp/remote.git"
git commit --quiet --allow-empty -m init
git push --quiet origin HEAD:refs/heads/main

# Installs a pre-receive hook on the throwaway remote that rejects the first
# $1 pushes of any build/* tag (then accepts), so allocate's retry/backoff
# path can be exercised deterministically instead of relying on a real race
# between two concurrent processes.
install_reject_hook() {
  printf '%s' "$1" >"$tmp/reject-max"
  printf '0' >"$tmp/reject-count"
  cat >"$tmp/remote.git/hooks/pre-receive" <<HOOK
#!/usr/bin/env bash
max=\$(cat "$tmp/reject-max")
count=\$(cat "$tmp/reject-count")
while read -r old new ref; do
  case "\$ref" in
    refs/tags/build/*)
      if [ "\$count" -lt "\$max" ]; then
        count=\$((count + 1))
        printf '%s' "\$count" >"$tmp/reject-count"
        echo "simulated rejection \$count/\$max for \$ref" >&2
        exit 1
      fi
      ;;
  esac
done
exit 0
HOOK
  chmod +x "$tmp/remote.git/hooks/pre-receive"
}
remove_reject_hook() {
  rm -f "$tmp/remote.git/hooks/pre-receive" "$tmp/reject-max" "$tmp/reject-count"
}

# First allocation starts at the floor.
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1000' || { echo "FAIL: first allocate: $out"; exit 1; }
echo "$out" | grep -qE '^version_name=[0-9]{2}\.[0-9]{1,2}\.1000$' || { echo "FAIL: version_name: $out"; exit 1; }

# Second allocation increments.
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1001' || { echo "FAIL: second allocate: $out"; exit 1; }

# Sorting is numeric, not lexicographic: 1002 must follow 1001, and later 1010 > 1009.
git tag -a build/1009 -m "26.7.1009" && git push --quiet origin build/1009
out=$("$SCRIPT" allocate --start 1000)
echo "$out" | grep -qx 'build_number=1010' || { echo "FAIL: numeric sort: $out"; exit 1; }

# resolve returns the stored version name, not a recomputed one.
git tag -a build/2000 -m "99.1.2000" && git push --quiet origin build/2000
out=$("$SCRIPT" resolve 2000)
echo "$out" | grep -qx 'build_number=2000' || { echo "FAIL: resolve number: $out"; exit 1; }
echo "$out" | grep -qx 'version_name=99.1.2000' || { echo "FAIL: resolve must read the annotation: $out"; exit 1; }

# resolve latest picks the numeric maximum.
out=$("$SCRIPT" resolve latest)
echo "$out" | grep -qx 'build_number=2000' || { echo "FAIL: resolve latest: $out"; exit 1; }

# resolve of a missing tag fails loudly.
if "$SCRIPT" resolve 4242 >/dev/null 2>&1; then
  echo "FAIL: resolve of a missing tag should exit non-zero"; exit 1
fi

# resolve must reject anything that is not `latest` or a plain integer. The
# target is interpolated straight into a `git fetch` refspec and a
# `git tag -l` pattern, so an unvalidated `*` matches every build tag and
# emits a multi-line `version_name=` into $GITHUB_OUTPUT, which GitHub then
# reads as an arbitrary set of step outputs.
for bad in '*' 'build/2000' '2000 2001' '-1' '2000.0' 'latest '; do
  if out=$("$SCRIPT" resolve "$bad" 2>&1); then
    echo "FAIL: resolve should reject '$bad' but succeeded: $out"; exit 1
  fi
  echo "$out" | grep -q 'version_name=' && { echo "FAIL: resolve '$bad' leaked an output line: $out"; exit 1; }
  echo "$out" | grep -q "must be 'latest' or a non-negative integer" \
    || { echo "FAIL: resolve '$bad' gave no validation message: $out"; exit 1; }
done

# A single lost race (the remote rejects the first push of the number the
# script picked) must be recovered silently: the delete-local-tag / re-read /
# backoff branch runs once, and the allocator still returns a well-formed,
# usable result. --start is well above every number used above so the
# outcome does not depend on prior test ordering.
install_reject_hook 1
out=$("$SCRIPT" allocate --start 5500 2>"$tmp/retry.err")
echo "$out" | grep -qx 'build_number=5500' || { echo "FAIL: retry recovery: $out"; exit 1; }
grep -q 'was taken, retrying' "$tmp/retry.err" || { echo "FAIL: retry branch not exercised: $(cat "$tmp/retry.err")"; exit 1; }
remove_reject_hook

# A permanently rejected push (protected tag, revoked credentials, network
# down -- not a race at all) must exhaust all 5 attempts, exit non-zero, and
# surface the real git error rather than just the generic retry message.
# `sleep` is stubbed to keep the exhausted-backoff path from costing 15s of
# real wall-clock time; it is exported so the child build-number.sh process
# (also bash) picks it up too.
install_reject_hook 99
sleep() { :; }
export -f sleep
if err=$("$SCRIPT" allocate --start 6000 2>&1 >/dev/null); then
  echo "FAIL: allocate should fail when every push is permanently rejected"; exit 1
fi
unset -f sleep
echo "$err" | grep -q 'could not allocate a build number after 5 attempts' || { echo "FAIL: missing final-failure message: $err"; exit 1; }
echo "$err" | grep -q 'simulated rejection' || { echo "FAIL: real push error not surfaced on terminal failure: $err"; exit 1; }
remove_reject_hook

# resolve latest against a remote that cannot be reached at all (bad path,
# no network, no credentials -- not a race, not an empty repo) must surface
# git's real ls-remote error. It must NOT be reported as "no build/* tags",
# which means something categorically different: a reachable remote that
# genuinely has no builds yet.
bogus_remote="$tmp/does-not-exist-$$.git"
if err=$("$SCRIPT" resolve latest --remote "$bogus_remote" 2>&1 >/dev/null); then
  echo "FAIL: resolve latest against an unreachable remote should exit non-zero"; exit 1
fi
echo "$err" | grep -q 'no build/\* tags' && { echo "FAIL: unreachable remote misreported as empty-but-reachable: $err"; exit 1; }
echo "$err" | grep -qi 'does not appear to be a git repository' || { echo "FAIL: real ls-remote error not surfaced: $err"; exit 1; }

# Credentials embedded in a remote URL must never reach the printed
# diagnostics, even when git's own error text would otherwise include them
# verbatim (unlike the common https:// libcurl transport, which already
# sanitizes its own error text, a malformed git:// URL echoes the raw
# "user:pass@host" straight into "unable to look up ..."). Port 1 on
# loopback fails instantly (connection/lookup refused) with no dependency on
# real network access, so this stays fast and deterministic.
secret="s3cr3t-token-do-not-leak"
cred_remote="git://x-access-token:${secret}@127.0.0.1:1/repo.git"
if err=$("$SCRIPT" resolve latest --remote "$cred_remote" 2>&1 >/dev/null); then
  echo "FAIL: resolve latest against a bogus credentialed remote should exit non-zero"; exit 1
fi
echo "$err" | grep -qF "$secret" && { echo "FAIL: credential leaked into diagnostics: $err"; exit 1; }
echo "$err" | grep -qi 'ls-remote error' || { echo "FAIL: expected an ls-remote error to still be reported: $err"; exit 1; }

echo "PASS: build-number.sh"
