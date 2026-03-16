#!/usr/bin/env bash
# Install or update dot-bin tools from the latest GitHub Release.
# Usage: curl -fsSL https://raw.githubusercontent.com/Honzys/dot-bin/master/install.sh | bash
set -euo pipefail

REPO="Honzys/dot-bin"
INSTALL_DIR="${DOT_BIN_INSTALL_DIR:-${HOME}/.local/bin}"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)
        echo "ERROR: Unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

TARBALL="dot-bin-${ARCH}.tar.gz"

echo "dot-bin installer"
echo "  Architecture: ${ARCH}"
echo "  Install dir:  ${INSTALL_DIR}"
echo ""

# Fetch latest release metadata
echo "Fetching latest release..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')

if [[ -z "$TAG" || "$TAG" == "null" ]]; then
    echo "ERROR: Could not determine latest release" >&2
    exit 1
fi
echo "  Release: ${TAG}"

# Find tarball and checksum download URLs
TARBALL_URL=$(echo "$RELEASE_JSON" | jq -r --arg name "$TARBALL" \
    '.assets[] | select(.name == $name) | .browser_download_url')
CHECKSUM_URL=$(echo "$RELEASE_JSON" | jq -r \
    '.assets[] | select(.name == "checksums.sha256") | .browser_download_url')

if [[ -z "$TARBALL_URL" || "$TARBALL_URL" == "null" ]]; then
    echo "ERROR: No ${TARBALL} asset found in release ${TAG}" >&2
    exit 1
fi

# Download to temp dir
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading ${TARBALL}..."
curl -fsSL -o "${TMPDIR}/${TARBALL}" "$TARBALL_URL"

# Verify checksum if available
if [[ -n "$CHECKSUM_URL" && "$CHECKSUM_URL" != "null" ]]; then
    echo "Verifying checksum..."
    curl -fsSL -o "${TMPDIR}/checksums.sha256" "$CHECKSUM_URL"
    EXPECTED=$(awk -v name="$TARBALL" '$NF == name {print $1}' "${TMPDIR}/checksums.sha256")
    ACTUAL=$(sha256sum "${TMPDIR}/${TARBALL}" | awk '{print $1}')
    if [[ "$ACTUAL" != "$EXPECTED" ]]; then
        echo "ERROR: Checksum mismatch" >&2
        echo "  Expected: ${EXPECTED}" >&2
        echo "  Actual:   ${ACTUAL}" >&2
        exit 1
    fi
    echo "  Checksum verified"
fi

# Download versions.json from release
VERSIONS_URL=$(echo "$RELEASE_JSON" | jq -r \
    '.assets[] | select(.name == "versions.json") | .browser_download_url')

# Extract to install dir
mkdir -p "$INSTALL_DIR"
echo "Extracting to ${INSTALL_DIR}..."
tar -xzf "${TMPDIR}/${TARBALL}" -C "$INSTALL_DIR"

# Save versions reference
if [[ -n "$VERSIONS_URL" && "$VERSIONS_URL" != "null" ]]; then
    curl -fsSL -o "${INSTALL_DIR}/.dot-bin-versions.json" "$VERSIONS_URL"
fi

# Check if install dir is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
    echo ""
    echo "WARNING: ${INSTALL_DIR} is not in your PATH."
    echo "Add this to your shell config:"
    echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi

echo ""
echo "Done! Installed dot-bin ${TAG} (${ARCH})"
