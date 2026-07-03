#!/usr/bin/env bash
# Downloads the xjasonlyu/tun2socks binary for macOS arm64 into
# Sources/XrayClient/Resources/. Used for the TUN (full-traffic) mode.
set -euo pipefail

REPO="xjasonlyu/tun2socks"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/XrayClient/Resources"
mkdir -p "${DEST_DIR}"

ARCH="$(uname -m)"
case "${ARCH}" in
  arm64)  ASSET="tun2socks-darwin-arm64.zip" ;;
  x86_64) ASSET="tun2socks-darwin-amd64.zip" ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

# Resolve latest tag via the releases/latest redirect (avoids API 403).
echo "Resolving latest tun2socks release..."
TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
  "https://github.com/${REPO}/releases/latest" | sed -E 's#.*/tag/##')"
if [ -z "${TAG}" ]; then
  echo "Could not resolve latest release tag." >&2
  exit 1
fi
echo "Latest release: ${TAG}"

URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Downloading ${ASSET}..."
curl -fsSL "${URL}" -o "${TMP}/t2s.zip"

echo "Extracting..."
unzip -o -q "${TMP}/t2s.zip" -d "${TMP}/extracted"

# The archive contains a binary named like tun2socks-darwin-arm64.
BIN="$(find "${TMP}/extracted" -type f -name 'tun2socks*' | head -1)"
if [ -z "${BIN}" ]; then
  echo "tun2socks binary not found in archive." >&2
  exit 1
fi
cp "${BIN}" "${DEST_DIR}/tun2socks"
chmod +x "${DEST_DIR}/tun2socks"
xattr -dr com.apple.quarantine "${DEST_DIR}/tun2socks" 2>/dev/null || true

echo "Installed tun2socks -> ${DEST_DIR}/tun2socks"
"${DEST_DIR}/tun2socks" --version 2>/dev/null || true
