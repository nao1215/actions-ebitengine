#!/usr/bin/env bash
#
# release_meta.sh — normalize a release version into moving action tag channels.
#
set -euo pipefail

die() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

set_output() {
  local name="$1" value="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
  fi
}

resolve_release_meta() {
  local requested="${1:-${INPUT_RELEASE_VERSION:-}}"
  requested="$(printf '%s' "$requested" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  if [ -z "$requested" ]; then
    printf '%s\n' "ERROR: release version is required (expected vX.Y.Z or X.Y.Z)" >&2
    return 1
  fi

  local major minor patch
  if [[ "$requested" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
  else
    printf '%s\n' "ERROR: release version must be plain semver (expected vX.Y.Z or X.Y.Z, got '${requested}')" >&2
    return 1
  fi

  RELEASE_TAG="v${major}.${minor}.${patch}"
  MAJOR_TAG="v${major}"
  MINOR_TAG="v${major}.${minor}"
}

emit_release_meta() {
  set_output "release-tag" "$RELEASE_TAG"
  set_output "major-tag" "$MAJOR_TAG"
  set_output "minor-tag" "$MINOR_TAG"
}
