#!/usr/bin/env bash
#
# packages_test.sh — check that the package list is resolved correctly for
# every OS, package manager and input combination (nothing is installed).
#
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=install.sh
source "${here}/install.sh"

failures=0

check() {
  local desc="$1" os="$2" pm="$3" xvfb="$4" extra="$5" want_pm="$6" want="$7"
  RUNNER_OS="$os" PKG_MANAGER="$pm" INPUT_XVFB="$xvfb" INPUT_EXTRA_PACKAGES="$extra"
  resolve_packages
  if [ "$PKG_MANAGER" != "$want_pm" ] || [ "$PACKAGES" != "$want" ]; then
    printf 'FAIL: %s -> PM=%s PACKAGES=%s (want PM=%s PACKAGES=%s)\n' "$desc" "$PKG_MANAGER" "$PACKAGES" "$want_pm" "$want"
    failures=$((failures + 1))
  else
    printf 'ok:   %s\n' "$desc"
  fi
}

check "ubuntu default"      Linux apt false ""                  apt  "$APT_PACKAGES"
check "ubuntu with xvfb"    Linux apt true  ""                  apt  "$APT_PACKAGES xvfb"
check "ubuntu xvfb=Yes"     Linux apt Yes   ""                  apt  "$APT_PACKAGES xvfb"
check "ubuntu extra"        Linux apt false "  libfoo   libbar " apt "$APT_PACKAGES libfoo libbar"
check "fedora with xvfb"    Linux dnf true  ""                  dnf  "$DNF_PACKAGES xorg-x11-server-Xvfb"
check "macOS needs nothing" macOS ""  true  "libfoo"            none ""
check "windows needs nothing" Windows "" false ""               none ""

for v in true TRUE yes 1 on; do
  if is_true "$v"; then printf 'ok:   is_true %s\n' "$v"; else printf 'FAIL: is_true %s\n' "$v"; failures=$((failures + 1)); fi
done
for v in false no 0 "" off; do
  if is_true "$v"; then printf 'FAIL: is_true "%s" accepted\n' "$v"; failures=$((failures + 1)); else printf 'ok:   is_true "%s" rejected\n' "$v"; fi
done

if (RUNNER_OS="FreeBSD" resolve_packages) >/dev/null 2>&1; then
  printf 'FAIL: unsupported OS was accepted\n'
  failures=$((failures + 1))
else
  printf 'ok:   unsupported OS rejected\n'
fi

if [ "$failures" -ne 0 ]; then
  printf '%d test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'all package tests passed\n'
