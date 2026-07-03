#!/usr/bin/env bash
# Downloads the Xray-core binary for macOS into Sources/XrayClient/Resources/.
# Detects CPU architecture (arm64 / x86_64) automatically.
set -euo pipefail

REPO="XTLS/Xray-core"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/Sources/XrayClient/Resources"
mkdir -p "$DEST_DIR"

ARCH="$(uname -m)"
case "$ARCH" in
  arm64)  ASSET="Xray-macos-arm64-v8a.zip" ;;
  x86_64) ASSET="Xray-macos-64.zip" ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# Resolve the latest release tag. Use the releases/latest redirect rather than
# the GitHub API to avoid unauthenticated rate limits (HTTP 403).
echo "Resolving latest Xray-core release..."
TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
  "https://github.com/$REPO/releases/latest" | sed -E 's#.*/tag/##')"
if [ -z "${TAG}" ]; then
  echo "Could not resolve latest release tag." >&2
  exit 1
fi
echo "Latest release: ${TAG}"

URL="https://github.com/$REPO/releases/download/${TAG}/${ASSET}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading ${ASSET}..."
curl -fsSL "${URL}" -o "$TMP/xray.zip"

echo "Extracting..."
unzip -o -q "$TMP/xray.zip" -d "$TMP/extracted"

cp "$TMP/extracted/xray" "$DEST_DIR/xray"
chmod +x "$DEST_DIR/xray"

# Remove the quarantine attribute so Gatekeeper allows execution.
xattr -dr com.apple.quarantine "$DEST_DIR/xray" 2>/dev/null || true

echo "Installed xray -> $DEST_DIR/xray"
"$DEST_DIR/xray" version || true
