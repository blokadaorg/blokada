#!/usr/bin/env bash
#
# Allocates and resolves the forever-incrementing build number that drives both
# the version name (YY.M.BUILD) and the store version code (offset + BUILD).
#
# The number lives in annotated git tags named build/<N>, whose subject is the
# version name. Storing the name matters: it is baked into the binary at build
# time, so a build allocated in July stays 26.7.<N> even when promoted in
# August. Recomputing it at release time would address a version that does not
# exist.
#
# The tag push is the lock -- it either wins or fails, and a loser retries.
set -euo pipefail

usage() {
  echo "usage: $0 allocate [--start N] [--remote NAME]" >&2
  echo "       $0 resolve <N|latest> [--remote NAME]" >&2
  exit 2
}

REMOTE=origin
START=1000
CMD=${1:-}
[ -n "$CMD" ] || usage
shift || true

TARGET=""
if [ "$CMD" = "resolve" ]; then
  TARGET=${1:-}
  [ -n "$TARGET" ] || usage
  shift || true

  # The target is interpolated into a `git fetch` refspec and a `git tag -l`
  # pattern, so it has to be a single build number and nothing else. `*` would
  # otherwise match every build tag and print one `version_name=` line per tag
  # into $GITHUB_OUTPUT.
  if [ "$TARGET" != "latest" ]; then
    case "$TARGET" in
      *[!0-9]*)
        echo "Error: build number must be 'latest' or a non-negative integer, got '$TARGET'" >&2
        exit 2
        ;;
    esac
  fi
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --start)  START=$2; shift 2 ;;
    --remote) REMOTE=$2; shift 2 ;;
    *) usage ;;
  esac
done

# Strips credentials out of diagnostic text before it is ever printed. Most
# git transports (libcurl-based https://) already sanitize the URL in their
# own error text, but not all of them do -- e.g. a malformed git:// URL
# echoes its raw "user:pass@host" verbatim in "unable to look up ...". A
# CI-style credential-embedded remote URL must never reach a workflow log
# through this script, regardless of which transport leaked it.
redact() {
  printf '%s' "$1" | sed -E 's#([[:alnum:]+.-]+://)?[^[:space:]/@]+:[^[:space:]/@]+@#\1#g'
}

# Highest existing build number on the remote, or empty when there are none.
# `sort -n` is required: lexicographic order would put 999 above 1010.
#
# Callers use this as `x=$(highest)`, which runs in a subshell -- a global
# variable set in here to signal "this failed because ls-remote itself
# failed" would be invisible to the caller once that subshell exits, so the
# only channel back out is the captured stdout/return-code pair itself:
#   - success, non-empty stdout: the highest build number.
#   - failure (rc=1), empty stdout: the remote is reachable but genuinely
#     has no build/* tags yet -- not an error.
#   - failure (rc=1), non-empty stdout: ls-remote itself failed (network,
#     auth, protected refs); stdout carries the redacted git error text
#     instead of a number, and it is never a bare integer, so callers can
#     tell the two failure cases apart without extra state.
highest() {
  local raw rc
  raw=$(git ls-remote --tags "$REMOTE" 'refs/tags/build/*' 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    redact "$raw"
    return 1
  fi
  printf '%s\n' "$raw" \
    | sed 's#.*refs/tags/build/##' \
    | grep -E '^[0-9]+$' \
    | sort -n | tail -1
}

case "$CMD" in
  allocate)
    last_push_err=""
    last_ls_err=""
    for attempt in 1 2 3 4 5; do
      if last=$(highest); then
        last_ls_err=""
      else
        # A genuinely empty remote leaves $last empty too; a real ls-remote
        # failure leaves the (redacted) git error text in it instead.
        [ -z "$last" ] || last_ls_err="$last"
        last=""
      fi
      next=$(( ${last:-$((START - 1))} + 1 ))
      [ "$next" -ge "$START" ] || next=$START
      version="$(date +%y).$(date +%-m).$next"

      git tag -a "build/$next" -m "$version" 2>/dev/null || git tag -f -a "build/$next" -m "$version"
      # Capture the real push output instead of discarding it: a lost race
      # (expected, quiet) and a genuine infrastructure failure (auth, network,
      # protected tag) look identical unless we keep the message around for
      # the terminal failure below.
      if push_err=$(git push --quiet "$REMOTE" "build/$next" 2>&1); then
        echo "build_number=$next"
        echo "version_name=$version"
        exit 0
      fi
      push_err=$(redact "$push_err")

      # Someone else took it (or a real failure). Drop the local tag and
      # re-read; stay quiet here since a lost race is normal on every attempt
      # but the last one.
      git tag -d "build/$next" >/dev/null 2>&1 || true
      echo "build/$next was taken, retrying ($attempt/5)" >&2
      last_push_err="$push_err"
      sleep "$attempt"
    done
    echo "Error: could not allocate a build number after 5 attempts" >&2
    if [ -n "$last_ls_err" ]; then
      echo "Last ls-remote error: $last_ls_err" >&2
    fi
    if [ -n "$last_push_err" ]; then
      echo "Last push error: $last_push_err" >&2
    fi
    exit 1
    ;;

  resolve)
    if [ "$TARGET" = "latest" ]; then
      if ! TARGET=$(highest); then
        if [ -n "$TARGET" ]; then
          # A real lookup failure (git error text in $TARGET) is a different
          # condition than "no builds yet" (empty $TARGET) and must not be
          # reported as the latter.
          echo "Error: could not list build/* tags on $(redact "$REMOTE")" >&2
          echo "ls-remote error: $TARGET" >&2
          exit 1
        fi
        TARGET=""
      fi
      [ -n "$TARGET" ] || { echo "Error: no build/* tags on $(redact "$REMOTE")" >&2; exit 1; }
    fi

    # `+` forces the local ref to match the remote even if a stale local
    # build/$TARGET already exists (e.g. a persistent self-hosted checkout),
    # rather than silently keeping the diverged local one.
    fetch_err=""
    fetch_err=$(git fetch --quiet "$REMOTE" "+refs/tags/build/$TARGET:refs/tags/build/$TARGET" 2>&1) || true
    fetch_err=$(redact "$fetch_err")
    version=$(git tag -l --format='%(contents:subject)' "build/$TARGET")
    if [ -z "$version" ]; then
      echo "Error: build/$TARGET not found, or carries no version annotation" >&2
      if [ -n "$fetch_err" ]; then
        echo "Fetch error: $fetch_err" >&2
      fi
      exit 1
    fi

    echo "build_number=$TARGET"
    echo "version_name=$version"
    ;;

  *) usage ;;
esac
