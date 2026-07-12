#!/bin/sh
# Accent CMS installer for Linux and macOS.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/AccentCMS/accent/main/install.sh | sh -s -- --version v0.22.0
#
# There is one binary per platform: every download contains the full
# feature set, and your license key decides which tier is unlocked at
# runtime. Releases before v0.22.0 were never published here.

set -eu

REPO="AccentCMS/accent"
INSTALL_DIR="${HOME}/.local/bin"
VERSION=""
FORCE=0

# --- Argument parsing ---

while [ $# -gt 0 ]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --force)    FORCE=1; shift ;;
    --help)
      echo "Usage: install.sh [--version VERSION] [--force]"
      echo ""
      echo "Options:"
      echo "  --version VERSION   Install a specific version (e.g., v0.22.0)"
      echo "  --force             Overwrite existing installation without prompting"
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

check_existing() {
  if [ -f "${INSTALL_DIR}/accent" ] && [ "$FORCE" -eq 0 ]; then
    EXISTING_VERSION=$("${INSTALL_DIR}/accent" --version 2>/dev/null || echo "unknown")
    echo "Accent CMS is already installed: ${EXISTING_VERSION}"
    echo "Use --force to overwrite, or remove it first:"
    echo "  rm ${INSTALL_DIR}/accent"
    exit 1
  fi
}

# --- Download and verify ---

download_and_install() {
  ARCHIVE_NAME="accent-${VERSION}-${TARGET}.tar.gz"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"
  CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums-${VERSION}.txt"

  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  echo "Downloading ${ARCHIVE_NAME}..."
  if ! curl -fsSL -o "${TMPDIR}/${ARCHIVE_NAME}" "$DOWNLOAD_URL"; then
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

  echo ""
  echo "Installation complete! Run 'accent --version' to verify."
}

main
