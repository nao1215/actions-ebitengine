#!/usr/bin/env bash
#
# release_meta_test.sh — check that release tags normalize into moving channels.
#
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=release_meta.sh
source "${here}/release_meta.sh"

failures=0

check() {
  local input="$1" want_release="$2" want_major="$3" want_minor="$4"
  RELEASE_TAG="" MAJOR_TAG="" MINOR_TAG=""
  if ! resolve_release_meta "$input"; then
    printf 'FAIL: %-8s -> resolver returned nonzero\n' "$input"
    failures=$((failures + 1))
    return
  fi
  if [ "$RELEASE_TAG" != "$want_release" ] || [ "$MAJOR_TAG" != "$want_major" ] || [ "$MINOR_TAG" != "$want_minor" ]; then
    printf 'FAIL: %-8s -> RELEASE=%s MAJOR=%s MINOR=%s (want RELEASE=%s MAJOR=%s MINOR=%s)\n' \
      "$input" "$RELEASE_TAG" "$MAJOR_TAG" "$MINOR_TAG" "$want_release" "$want_major" "$want_minor"
    failures=$((failures + 1))
  else
    printf 'ok:   %-8s -> RELEASE=%s MAJOR=%s MINOR=%s\n' "$input" "$RELEASE_TAG" "$MAJOR_TAG" "$MINOR_TAG"
  fi
}

check_invalid() {
  local input="$1"
  if resolve_release_meta "$input" >/dev/null 2>&1; then
    printf 'FAIL: %-8s -> unexpectedly accepted invalid release tag\n' "$input"
    failures=$((failures + 1))
  else
    printf 'ok:   %-8s -> rejected invalid release tag\n' "$input"
  fi
}

check "v0.1.1" "v0.1.1" "v0" "v0.1"
check "0.2.3"  "v0.2.3" "v0" "v0.2"
check " 1.4.0 " "v1.4.0" "v1" "v1.4"
check " v2.3.4 " "v2.3.4" "v2" "v2.3"

check_invalid "latest"
check_invalid "v0.1"
check_invalid "v1. 2.3"
check_invalid "v0.1.0-rc1"

if [ "$failures" -ne 0 ]; then
  printf '%d test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'all release-tag tests passed\n'
