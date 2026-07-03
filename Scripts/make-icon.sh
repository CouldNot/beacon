#!/usr/bin/env bash
# Generates Resources/AppIcon.icns from a 1024px master rendered by gen-icon.swift.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

mkdir -p Resources
TMP="$(mktemp -d)"
MASTER="${TMP}/icon-1024.png"

echo "Rendering master icon..."
swift Scripts/gen-icon.swift "${MASTER}"

ICONSET="${TMP}/AppIcon.iconset"
mkdir -p "${ICONSET}"

# macOS iconset sizes (1x and 2x).
sips -z 16 16     "${MASTER}" --out "${ICONSET}/icon_16x16.png"      >/dev/null
sips -z 32 32     "${MASTER}" --out "${ICONSET}/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "${MASTER}" --out "${ICONSET}/icon_32x32.png"      >/dev/null
sips -z 64 64     "${MASTER}" --out "${ICONSET}/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "${MASTER}" --out "${ICONSET}/icon_128x128.png"    >/dev/null
sips -z 256 256   "${MASTER}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${MASTER}" --out "${ICONSET}/icon_256x256.png"    >/dev/null
sips -z 512 512   "${MASTER}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${MASTER}" --out "${ICONSET}/icon_512x512.png"    >/dev/null
cp "${MASTER}" "${ICONSET}/icon_512x512@2x.png"

iconutil -c icns "${ICONSET}" -o "Resources/AppIcon.icns"
echo "Wrote Resources/AppIcon.icns"
rm -rf "${TMP}"
