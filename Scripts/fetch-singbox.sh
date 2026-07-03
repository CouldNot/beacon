#!/usr/bin/env bash
# Downloads the sing-box binary for macOS into Sources/XrayClient/Resources/.
# sing-box is the second core, handling QUIC-based protocols that Xray-core
# cannot (Hysteria2, TUIC). Detects CPU architecture (arm64 / x86_64).
set -euo pipefail

REPO="SagerNet/sing-box"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/XrayClient/Resources"
mkdir -p "${DEST_DIR}"

ARCH="$(uname -m)"
case "${ARCH}" in
  arm64)  GOARCH="arm64" ;;
  x86_64) GOARCH="amd64" ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 1 ;;
esac

# Resolve latest tag via the releases/latest redirect (avoids API 403).
echo "Resolving latest sing-box release..."
TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
  "https://github.com/${REPO}/releases/latest" | sed -E 's#.*/tag/##')"
if [ -z "${TAG}" ]; then
  echo "Could not resolve latest release tag." >&2
  exit 1
fi
echo "Latest release: ${TAG}"

# Release assets are named like sing-box-1.10.1-darwin-arm64.tar.gz (no leading v).
VER="${TAG#v}"
ASSET="sing-box-${VER}-darwin-${GOARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "Downloading ${ASSET}..."
curl -fsSL "${URL}" -o "${TMP}/singbox.tar.gz"

echo "Extracting..."
tar -xzf "${TMP}/singbox.tar.gz" -C "${TMP}"

BIN="$(find "${TMP}" -type f -name 'sing-box' | head -1)"
if [ -z "${BIN}" ]; then
  echo "sing-box binary not found in archive." >&2
  exit 1
fi
cp "${BIN}" "${DEST_DIR}/sing-box"
chmod +x "${DEST_DIR}/sing-box"
xattr -dr com.apple.quarantine "${DEST_DIR}/sing-box" 2>/dev/null || true

echo "Installed sing-box -> ${DEST_DIR}/sing-box"
"${DEST_DIR}/sing-box" version 2>/dev/null || true
