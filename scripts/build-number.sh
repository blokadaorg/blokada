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
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --start)  START=$2; shift 2 ;;
    --remote) REMOTE=$2; shift 2 ;;
    *) usage ;;
  esac
done

# Highest existing build number on the remote, or START-1 when there are none.
# `sort -n` is required: lexicographic order would put 999 above 1010.
highest() {
  git ls-remote --tags "$REMOTE" 'refs/tags/build/*' \
    | sed 's#.*refs/tags/build/##' \
    | grep -E '^[0-9]+$' \
    | sort -n | tail -1
}

case "$CMD" in
  allocate)
    for attempt in 1 2 3 4 5; do
      last=$(highest || true)
      next=$(( ${last:-$((START - 1))} + 1 ))
      [ "$next" -ge "$START" ] || next=$START
      version="$(date +%y).$(date +%-m).$next"

      git tag -a "build/$next" -m "$version" 2>/dev/null || git tag -f -a "build/$next" -m "$version"
      if git push --quiet "$REMOTE" "build/$next" 2>/dev/null; then
        echo "build_number=$next"
        echo "version_name=$version"
        exit 0
      fi

      # Someone else took it. Drop the local tag and re-read.
      git tag -d "build/$next" >/dev/null 2>&1 || true
      echo "build/$next was taken, retrying ($attempt/5)" >&2
      sleep "$attempt"
    done
    echo "Error: could not allocate a build number after 5 attempts" >&2
    exit 1
    ;;

  resolve)
    if [ "$TARGET" = "latest" ]; then
      TARGET=$(highest || true)
      [ -n "$TARGET" ] || { echo "Error: no build/* tags on $REMOTE" >&2; exit 1; }
    fi

    git fetch --quiet "$REMOTE" "refs/tags/build/$TARGET:refs/tags/build/$TARGET" 2>/dev/null || true
    version=$(git tag -l --format='%(contents:subject)' "build/$TARGET")
    if [ -z "$version" ]; then
      echo "Error: build/$TARGET not found, or carries no version annotation" >&2
      exit 1
    fi

    echo "build_number=$TARGET"
    echo "version_name=$version"
    ;;

  *) usage ;;
esac
