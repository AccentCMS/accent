#!/bin/sh
# Accent CMS installer for Linux and macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh -s -- --version v0.22.0
#
# Reinstalling over an existing install requires --force. That means
# putting the flag after `sh -s --`; a flag placed after the URL instead
# is consumed by curl (which does not understand it), not sh, and never
# reaches this script:
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh -s -- --force
#
# ACCENT_FORCE and ACCENT_VERSION are environment-variable equivalents of
# --force and --version, immune to that pipe-argument mistake because
# they are set on the `sh` side of the pipe, not appended to the curl
# command line. An explicit CLI flag always wins over its env var:
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | ACCENT_FORCE=1 sh
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | ACCENT_VERSION=v0.22.0 sh
# Versions are accepted with or without the v prefix (0.22.0 == v0.22.0).
#
# There is one binary per platform: every download contains the full
# feature set, and your license key decides which tier is unlocked at
# runtime. Releases before v0.22.0 were never published here.

set -eu

REPO="AccentCMS/accent"
INSTALL_DIR="${HOME}/.local/bin"

# Env-var defaults, applied before argument parsing so an explicit CLI
# flag always overrides. Any ACCENT_FORCE value other than empty or "0"
# behaves like --force.
VERSION="${ACCENT_VERSION:-}"
case "${ACCENT_FORCE:-}" in
  '' | 0) FORCE=0 ;;
  *)      FORCE=1 ;;
esac

# --- Argument parsing ---

while [ $# -gt 0 ]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    --help)
      echo "Usage: install.sh [--version VERSION] [--force]"
      echo ""
      echo "Options:"
      echo "  --version VERSION   Install a specific version (e.g., v0.22.0; the v prefix is optional)"
      echo "  --force             Overwrite existing installation without prompting"
      echo ""
      echo "Environment variable equivalents (useful piped through curl | sh,"
      echo "where a flag placed after the URL is consumed by curl, not sh):"
      echo "  ACCENT_VERSION      Same as --version"
      echo "  ACCENT_FORCE        Any value other than empty or 0 is the same as --force"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Platform detection ---

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Linux)  OS_NAME="linux" ;;
    Darwin) OS_NAME="macos" ;;
    *)
      echo "Error: Unsupported operating system: $OS"
      echo "Accent CMS supports Linux and macOS. For Windows, use install.ps1."
      exit 1
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)   TARGET_ARCH="x86_64" ;;
    aarch64|arm64)   TARGET_ARCH="aarch64" ;;
    *)
      echo "Error: Unsupported architecture: $ARCH"
      echo "Accent CMS supports x86_64 and aarch64/arm64."
      exit 1
      ;;
  esac

  case "${OS_NAME}-${TARGET_ARCH}" in
    linux-x86_64)   TARGET="x86_64-unknown-linux-gnu" ;;
    linux-aarch64)   TARGET="aarch64-unknown-linux-gnu" ;;
    macos-x86_64)   TARGET="x86_64-apple-darwin" ;;
    macos-aarch64)   TARGET="aarch64-apple-darwin" ;;
  esac

  echo "Detected platform: ${OS_NAME} ${TARGET_ARCH} (${TARGET})"
}

# --- Version resolution ---
#
# Resolves the latest tag from the releases/latest HTML redirect instead of
# the GitHub API: the redirect target ends in /tag/<version>, and this path
# is not subject to the unauthenticated API rate limit.

resolve_version() {
  if [ -n "$VERSION" ]; then
    # Accept the tag with or without its v prefix (--version 0.23.1 and
    # --version v0.23.1 are both natural spellings). Release tags always
    # carry the v, so normalize once here; this keeps the download URL
    # and the up-to-date comparison in check_existing consistent for
    # either spelling.
    case "$VERSION" in
      v*) ;;
      *)  VERSION="v${VERSION}" ;;
    esac
    echo "Installing version: $VERSION"
    return
  fi

  echo "Fetching latest version..."
  # Capture curl on its own (a pipeline would mask its exit status under
  # plain POSIX sh), then strip everything up to /tag/. On any failure --
  # curl error, no release yet (404), or an unexpected redirect target --
  # the result is empty or still contains slashes, which the guard below
  # rejects with actionable guidance instead of building a garbled URL.
  LATEST_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    "https://github.com/${REPO}/releases/latest") || LATEST_URL=""
  VERSION="${LATEST_URL##*/tag/}"

  case "$VERSION" in
  '' | */*)
    echo "Error: Could not determine latest version."
    echo "There may be no published release yet, or the network request failed."
    echo "Check https://github.com/${REPO}/releases or specify one with --version."
    exit 1
    ;;
  esac

  echo "Latest version: $VERSION"
}

# --- Check existing installation ---
#
# Runs after resolve_version, so $VERSION is already the resolved target
# (explicit --version, or the latest tag). That lets the up-to-date check
# below compare against it directly instead of re-resolving.

check_existing() {
  [ -f "${INSTALL_DIR}/accent" ] || return 0
  [ "$FORCE" -eq 0 ] || return 0

  EXISTING_VERSION=$("${INSTALL_DIR}/accent" --version 2>/dev/null || echo "unknown")
  EXISTING_NUM=$(echo "$EXISTING_VERSION" | awk '{print $2}')
  echo "Accent CMS is already installed: ${EXISTING_VERSION}"

  if [ -n "$EXISTING_NUM" ] && [ "v${EXISTING_NUM}" = "$VERSION" ]; then
    echo "Already up to date (${VERSION})."
    # A correct file at ${INSTALL_DIR}/accent is not the whole story: the
    # shell resolves accent by PATH order, and a stale binary earlier in
    # PATH silently wins (the b117 incident was exactly this, and a
    # cheerful "up to date" would be a false success signal there). Run
    # the same PATH checks a real install ends with before exiting.
    check_path
    check_shadowing
    exit 0
  fi

  echo "To reinstall or update in place, re-run with force:"
  echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sh -s -- --force"
  echo "or:"
  echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | ACCENT_FORCE=1 sh"
  echo "Or remove it first:"
  echo "  rm ${INSTALL_DIR}/accent"
  exit 1
}

# --- Download and verify ---
#
# The archive is the one multi-megabyte download in this script (the
# metadata probes below -- checksums, signature, signing key -- are all
# a few KB and stay silent). `--progress-bar` writes to stderr, which
# curl leaves untouched by the pipe into `sh`, so it renders even when
# this script itself was piped in. When stderr is not a terminal (CI
# logs, redirected output) a progress bar is just noise, so fall back to
# silent in that case.

download_and_install() {
  ARCHIVE_NAME="accent-${VERSION}-${TARGET}.tar.gz"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"
  CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums-${VERSION}.txt"

  if [ -t 2 ]; then
    PROGRESS='--progress-bar'
  else
    PROGRESS='-s'
  fi

  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "Downloading ${ARCHIVE_NAME}..."
  # shellcheck disable=SC2086  # $PROGRESS is always exactly one flag, never split
  if ! curl -fLS $PROGRESS -o "${TMPDIR}/${ARCHIVE_NAME}" "$DOWNLOAD_URL"; then
    echo "Error: Download failed."
    echo "URL: ${DOWNLOAD_URL}"
    echo ""
    echo "Check that the version exists (only v0.22.0 and later are published here):"
    echo "  https://github.com/${REPO}/releases"
    exit 1
  fi

  echo "Downloading checksums..."
  if curl -fsSL -o "${TMPDIR}/checksums.txt" "$CHECKSUMS_URL"; then
    verify_signature
    echo "Verifying checksum..."
    EXPECTED=$(grep "${ARCHIVE_NAME}" "${TMPDIR}/checksums.txt" | awk '{print $1}')
    if [ -z "$EXPECTED" ]; then
      echo "Warning: Archive not found in checksums file. Skipping verification."
    else
      if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL=$(sha256sum "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')
      elif command -v shasum >/dev/null 2>&1; then
        ACTUAL=$(shasum -a 256 "${TMPDIR}/${ARCHIVE_NAME}" | awk '{print $1}')
      else
        echo "Warning: No sha256sum or shasum found. Skipping checksum verification."
        ACTUAL="$EXPECTED"
      fi

      if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "Error: Checksum verification failed!"
        echo "  Expected: $EXPECTED"
        echo "  Actual:   $ACTUAL"
        echo "The downloaded file may be corrupted. Please try again."
        exit 1
      fi
      echo "Checksum verified."
    fi
  else
    echo "Warning: Could not download checksums. Skipping verification."
  fi

  echo "Extracting..."
  tar -xzf "${TMPDIR}/${ARCHIVE_NAME}" -C "${TMPDIR}"

  mkdir -p "$INSTALL_DIR"
  mv "${TMPDIR}/accent" "${INSTALL_DIR}/accent"
  chmod +x "${INSTALL_DIR}/accent"

  echo "Installed accent to ${INSTALL_DIR}/accent"
}

# --- GPG signature verification (best effort) ---
#
# Every release's checksums file carries a detached GPG signature. When gpg
# is available, verify it against the published release signing key; when it
# is not, warn and fall back to checksum-only verification.

verify_signature() {
  if ! command -v gpg >/dev/null 2>&1; then
    echo "Note: gpg not found; skipping signature verification (checksums still checked)."
    return
  fi

  SIG_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums-${VERSION}.txt.asc"
  KEY_URL="https://raw.githubusercontent.com/${REPO}/main/release-signing-key.asc"

  if ! curl -fsSL -o "${TMPDIR}/checksums.txt.asc" "$SIG_URL"; then
    echo "Warning: Could not download the checksums signature. Skipping signature verification."
    return
  fi
  if ! curl -fsSL -o "${TMPDIR}/release-signing-key.asc" "$KEY_URL"; then
    echo "Warning: Could not download the release signing key. Skipping signature verification."
    return
  fi

  GNUPGHOME=$(mktemp -d)
  export GNUPGHOME
  if gpg --quiet --import "${TMPDIR}/release-signing-key.asc" 2>/dev/null \
    && gpg --quiet --verify "${TMPDIR}/checksums.txt.asc" "${TMPDIR}/checksums.txt" 2>/dev/null; then
    echo "Signature verified."
  else
    echo "Error: GPG signature verification failed!"
    echo "The checksums file does not match the published release signing key."
    echo "Do not use this download; report it via https://github.com/${REPO}/discussions"
    rm -rf "$GNUPGHOME"
    unset GNUPGHOME
    exit 1
  fi
  rm -rf "$GNUPGHOME"
  unset GNUPGHOME
}

# --- PATH check ---

check_path() {
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
      echo ""
      echo "Note: ${INSTALL_DIR} is not on your PATH."
      echo "Add it by appending one of the following to your shell profile:"
      echo ""
      echo "  # For bash (~/.bashrc or ~/.bash_profile):"
      echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      echo ""
      echo "  # For zsh (~/.zshrc):"
      echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      echo ""
      echo "  # For fish (~/.config/fish/config.fish):"
      echo "  fish_add_path ~/.local/bin"
      echo ""
      echo "Then restart your shell or run: source ~/.bashrc"
      ;;
  esac
}

# --- Shadowing check ---
#
# The user's shell resolves `accent` by PATH order (plus its command
# hash), not by what this installer just wrote. A stale accent earlier
# in PATH -- a cargo-installed ~/.cargo/bin/accent is the common case --
# silently shadows the fresh install, and `accent --version` keeps
# reporting the old build while the user believes they upgraded. Surface
# the mismatch with both paths and versions whenever this script asserts
# the install dir holds the right binary -- after a fresh install, and
# equally on the "already up to date" path, where a cheerful success
# message would otherwise hide exactly this drift.

check_shadowing() {
  RESOLVED=$(command -v accent 2>/dev/null || true)
  [ -n "$RESOLVED" ] || return 0
  [ "$RESOLVED" = "${INSTALL_DIR}/accent" ] && return 0
  if [ "$RESOLVED" -ef "${INSTALL_DIR}/accent" ] 2>/dev/null; then
    return 0
  fi
  SHADOW_VERSION=$("$RESOLVED" --version 2>/dev/null || echo "unknown version")
  echo ""
  echo "Warning: 'accent' currently resolves to a different binary:"
  echo "  ${RESOLVED} (${SHADOW_VERSION})"
  echo "which shadows the up-to-date binary at ${INSTALL_DIR}/accent."
  echo "Remove the shadowing binary or move ${INSTALL_DIR} earlier in your"
  echo "PATH, then run 'hash -r' (bash/zsh) or restart your shell."
}

# --- Main ---

main() {
  echo "Accent CMS Installer"
  echo "==================="
  echo ""

  detect_platform
  resolve_version
  check_existing
  download_and_install
  check_path
  check_shadowing

  echo ""
  echo "Installation complete! Run 'accent --version' to verify."
}

main
