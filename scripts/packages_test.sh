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
  local desc="$1" os="$2" pm="$3" xvfb="$4" dev="$5" extra="$6" want_pm="$7" want="$8"
  RUNNER_OS="$os" PKG_MANAGER="$pm" INPUT_XVFB="$xvfb" INPUT_DEV="$dev" INPUT_EXTRA_PACKAGES="$extra"
  resolve_packages 2>/dev/null
  if [ "$PKG_MANAGER" != "$want_pm" ] || [ "$PACKAGES" != "$want" ]; then
    printf 'FAIL: %s -> PM=%s PACKAGES=%s (want PM=%s PACKAGES=%s)\n' "$desc" "$PKG_MANAGER" "$PACKAGES" "$want_pm" "$want"
    failures=$((failures + 1))
  else
    printf 'ok:   %s\n' "$desc"
  fi
}

check "ubuntu default"        Linux apt    false false ""                   apt    "$APT_PACKAGES"
check "ubuntu with xvfb"      Linux apt    true  false ""                   apt    "$APT_PACKAGES xvfb xauth"
check "ubuntu xvfb=Yes"       Linux apt    Yes   false ""                   apt    "$APT_PACKAGES xvfb xauth"
check "ubuntu dev"            Linux apt    false true  ""                   apt    "$APT_PACKAGES $APT_DEV"
check "ubuntu dev and xvfb"   Linux apt    true  true  ""                   apt    "$APT_PACKAGES $APT_DEV xvfb xauth"
check "ubuntu extra"          Linux apt    false false "  libfoo   libbar " apt    "$APT_PACKAGES libfoo libbar"
check "fedora with xvfb"      Linux dnf    true  false ""                   dnf    "$DNF_PACKAGES xorg-x11-server-Xvfb"
check "fedora dev"            Linux dnf    false true  ""                   dnf    "$DNF_PACKAGES $DNF_DEV"
check "arch with xvfb"        Linux pacman true  false ""                   pacman "$PACMAN_PACKAGES xorg-server-xvfb"
check "alpine with xvfb"      Linux apk    true  false ""                   apk    "$APK_PACKAGES xvfb-run"
check "void dev"              Linux xbps   false true  ""                   xbps   "$XBPS_PACKAGES $XBPS_DEV"
check "solus skips dev, xvfb" Linux eopkg  true  true  ""                   eopkg  "$EOPKG_PACKAGES"
check "macOS needs nothing"   macOS ""     true  true  "libfoo"             none   ""
check "windows needs nothing" Windows ""   false false ""                   none   ""

# the runtime set follows the Ebitengine install guide: no compiler or headers by default
case " $APT_PACKAGES $DNF_PACKAGES " in
  *" gcc "*|*"-dev "*|*"-devel "*) printf 'FAIL: the default packages include build tools\n'; failures=$((failures + 1)) ;;
  *) printf 'ok:   the default packages are runtime libraries only\n' ;;
esac

# libasound2t64 becomes libasound2 on releases without it
PACKAGES="libx11-6 libasound2t64 libxext6"
apt-cache() { return 1; }
apt_alsa_fix
if [ "$PACKAGES" = "libx11-6 libasound2 libxext6" ]; then printf 'ok:   older ALSA package name\n'; else printf 'FAIL: ALSA fallback -> %s\n' "$PACKAGES"; failures=$((failures + 1)); fi
PACKAGES="libx11-6 libasound2t64"
apt-cache() { return 0; }
apt_alsa_fix
if [ "$PACKAGES" = "libx11-6 libasound2t64" ]; then printf 'ok:   current ALSA package name kept\n'; else printf 'FAIL: ALSA kept -> %s\n' "$PACKAGES"; failures=$((failures + 1)); fi
unset -f apt-cache

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
