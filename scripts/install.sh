#!/usr/bin/env bash
#
# install.sh — install the system packages Ebitengine needs.
#
# Runs as a composite-action step on GitHub-hosted runners (Linux, macOS,
# Windows) and in Linux containers. Only Linux needs extra packages: since
# Ebitengine v2.10, desktop builds are pure Go (no C compiler, no headers), and
# a game loads X11, OpenGL and ALSA at run time. macOS and Windows runners
# already ship everything, so the script just reports that.
#
# With INPUT_DEV=true it also installs a C compiler and the development headers,
# for builds with cgo or Ebitengine before v2.10.
#
# See https://ebitengine.org/en/documents/install.html
set -euo pipefail

# The runtime libraries of the Ebitengine install guide, per package manager.
# ALSA on Debian and Ubuntu is "libasound2t64" on current releases and
# "libasound2" on older ones; install_packages picks the one the system has.
readonly APT_PACKAGES="libx11-6 libgl1 libglx-mesa0 libxcursor1 libxi6 libxinerama1 libxrandr2 libxrender1 libxext6 libasound2t64"
readonly DNF_PACKAGES="libX11 libglvnd-glx mesa-libGL mesa-dri-drivers libXcursor libXi libXinerama libXrandr libXrender libXext alsa-lib"
readonly PACMAN_PACKAGES="libx11 libglvnd mesa libxcursor libxi libxinerama libxrandr libxrender libxext alsa-lib"
readonly APK_PACKAGES="libx11 mesa-gl mesa-dri-gallium libxcursor libxi libxinerama libxrandr libxrender libxext alsa-lib"
readonly XBPS_PACKAGES="libX11 libglvnd mesa-dri libXcursor libXi libXinerama libXrandr libXrender libXext alsa-lib"
readonly EOPKG_PACKAGES="libx11 libglvnd mesalib libxcursor libxi libxinerama libxrandr libxrender libxext alsa-lib"

# A C compiler and the development headers (input dev), for cgo builds.
readonly APT_DEV="gcc libc6-dev pkg-config libx11-dev libgl1-mesa-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev libxxf86vm-dev libasound2-dev"
readonly DNF_DEV="gcc pkg-config libX11-devel mesa-libGL-devel mesa-libGLES-devel libXcursor-devel libXi-devel libXinerama-devel libXrandr-devel libXxf86vm-devel alsa-lib-devel"
readonly PACMAN_DEV="gcc pkgconf"
readonly APK_DEV="build-base pkgconf libx11-dev mesa-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev alsa-lib-dev"
readonly XBPS_DEV="gcc pkg-config libX11-devel libglvnd-devel libXcursor-devel libXi-devel libXinerama-devel libXrandr-devel alsa-lib-devel"

# Xvfb, to run games and tests headless (input xvfb).
readonly APT_XVFB="xvfb"
readonly DNF_XVFB="xorg-x11-server-Xvfb"
readonly PACMAN_XVFB="xorg-server-xvfb"
readonly APK_XVFB="xvfb-run"
readonly XBPS_XVFB="xorg-server-xvfb"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "WARNING: $*" >&2; }
die() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

# Emit a GitHub Actions step output when running in Actions; harmless locally.
set_output() {
  local name="$1" value="$2"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$name" "$value" >>"$GITHUB_OUTPUT"
  fi
}

# Run a command as root: directly when already root (containers), via sudo otherwise.
as_root() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "root privileges are required to install packages, but sudo is not available"
  fi
}

# Accept the usual spellings of a boolean input.
is_true() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true|yes|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Decide what to install. Sets PKG_MANAGER and PACKAGES.
# ---------------------------------------------------------------------------
detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  elif command -v apk >/dev/null 2>&1; then
    PKG_MANAGER="apk"
  elif command -v xbps-install >/dev/null 2>&1; then
    PKG_MANAGER="xbps"
  elif command -v eopkg >/dev/null 2>&1; then
    PKG_MANAGER="eopkg"
  else
    die "no supported package manager found (expected apt-get, dnf, pacman, apk, xbps-install or eopkg)"
  fi
}

resolve_packages() {
  local os="${RUNNER_OS:-}"
  PACKAGES=""
  case "$os" in
    Linux) ;;
    macOS|Windows)
      PKG_MANAGER="none"
      return 0
      ;;
    *) die "unsupported runner OS: '${os}' (expected Linux, macOS, or Windows)" ;;
  esac

  local base dev xvfb
  case "$PKG_MANAGER" in
    apt) base="$APT_PACKAGES" dev="$APT_DEV" xvfb="$APT_XVFB" ;;
    dnf) base="$DNF_PACKAGES" dev="$DNF_DEV" xvfb="$DNF_XVFB" ;;
    pacman) base="$PACMAN_PACKAGES" dev="$PACMAN_DEV" xvfb="$PACMAN_XVFB" ;;
    apk) base="$APK_PACKAGES" dev="$APK_DEV" xvfb="$APK_XVFB" ;;
    xbps) base="$XBPS_PACKAGES" dev="$XBPS_DEV" xvfb="$XBPS_XVFB" ;;
    eopkg) base="$EOPKG_PACKAGES" dev="" xvfb="" ;;
    *) die "unsupported package manager: '${PKG_MANAGER}'" ;;
  esac

  PACKAGES="$base"
  if is_true "${INPUT_DEV:-false}"; then
    if [ -n "$dev" ]; then
      PACKAGES="${PACKAGES} ${dev}"
    else
      warn "the dev input is not supported with ${PKG_MANAGER}; install a C compiler and the headers yourself"
    fi
  fi
  if is_true "${INPUT_XVFB:-false}"; then
    if [ -n "$xvfb" ]; then
      PACKAGES="${PACKAGES} ${xvfb}"
    else
      warn "the xvfb input is not supported with ${PKG_MANAGER}; install Xvfb yourself"
    fi
  fi

  local extra
  extra="$(printf '%s' "${INPUT_EXTRA_PACKAGES:-}" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//')"
  if [ -n "$extra" ]; then
    PACKAGES="${PACKAGES} ${extra}"
  fi
}

# apt_alsa_fix uses "libasound2" on Debian and Ubuntu releases that do not have
# "libasound2t64" yet (Ubuntu before 24.04, Debian before 13).
apt_alsa_fix() {
  if ! apt-cache show libasound2t64 >/dev/null 2>&1; then
    PACKAGES="$(printf '%s' "$PACKAGES" | sed -E 's/(^| )libasound2t64( |$)/\1libasound2\2/')"
  fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install_packages() {
  case "$PKG_MANAGER" in
    apt)
      if is_true "${INPUT_APT_UPDATE:-true}"; then
        log "Updating the apt package index..."
        as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
      fi
      apt_alsa_fix
      ;;
  esac
  local -a pkgs
  read -r -a pkgs <<<"$PACKAGES"
  log "Installing: ${PACKAGES}"
  case "$PKG_MANAGER" in
    apt) as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${pkgs[@]}" ;;
    dnf) as_root dnf install -y -q "${pkgs[@]}" ;;
    pacman) as_root pacman -Sy --noconfirm --needed "${pkgs[@]}" ;;
    apk) as_root apk add --no-cache "${pkgs[@]}" ;;
    xbps) as_root xbps-install -Sy "${pkgs[@]}" ;;
    eopkg) as_root eopkg install -y "${pkgs[@]}" ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  PKG_MANAGER=""
  if [ "${RUNNER_OS:-}" = "Linux" ]; then
    detect_package_manager
  fi
  resolve_packages

  if [ "$PKG_MANAGER" = "none" ]; then
    log "${RUNNER_OS} needs no extra packages for Ebitengine; nothing to install"
  else
    install_packages
  fi

  set_output "packages" "$PACKAGES"
  set_output "package-manager" "$PKG_MANAGER"
}

# Only run when executed directly, so tests can source the functions above.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
