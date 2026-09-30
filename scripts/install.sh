#!/usr/bin/env bash
#
# install.sh — install the system packages Ebitengine needs.
#
# Runs as a composite-action step on GitHub-hosted runners (Linux, macOS,
# Windows) and in Linux containers. Ebitengine only needs extra packages on
# Linux (the OpenGL, X11 and ALSA headers used through cgo); macOS and Windows
# runners already ship everything, so the script just reports that.
#
# See https://ebitengine.org/en/documents/install.html
set -euo pipefail

# Packages listed in the Ebitengine install guide.
readonly APT_PACKAGES="gcc libc6-dev libgl1-mesa-dev libxcursor-dev libxi-dev libxinerama-dev libxrandr-dev libxxf86vm-dev libasound2-dev pkg-config"
readonly DNF_PACKAGES="gcc mesa-libGL-devel mesa-libGLES-devel libXrandr-devel libXcursor-devel libXinerama-devel libXi-devel libXxf86vm-devel alsa-lib-devel pkg-config"
readonly APT_XVFB="xvfb"
readonly DNF_XVFB="xorg-x11-server-Xvfb"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { printf '%s\n' "==> $*"; }
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
  else
    die "no supported package manager found (expected apt-get or dnf)"
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

  case "$PKG_MANAGER" in
    apt)
      PACKAGES="$APT_PACKAGES"
      if is_true "${INPUT_XVFB:-false}"; then PACKAGES="${PACKAGES} ${APT_XVFB}"; fi
      ;;
    dnf)
      PACKAGES="$DNF_PACKAGES"
      if is_true "${INPUT_XVFB:-false}"; then PACKAGES="${PACKAGES} ${DNF_XVFB}"; fi
      ;;
    *) die "unsupported package manager: '${PKG_MANAGER}'" ;;
  esac

  local extra
  extra="$(printf '%s' "${INPUT_EXTRA_PACKAGES:-}" | tr -s '[:space:]' ' ' | sed -E 's/^ //; s/ $//')"
  if [ -n "$extra" ]; then
    PACKAGES="${PACKAGES} ${extra}"
  fi
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install_packages() {
  local -a pkgs
  read -r -a pkgs <<<"$PACKAGES"
  case "$PKG_MANAGER" in
    apt)
      if is_true "${INPUT_APT_UPDATE:-true}"; then
        log "Updating the apt package index..."
        as_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
      fi
      log "Installing: ${PACKAGES}"
      as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${pkgs[@]}"
      ;;
    dnf)
      log "Installing: ${PACKAGES}"
      as_root dnf install -y -q "${pkgs[@]}"
      ;;
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
