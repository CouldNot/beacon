#!/usr/bin/env bash
# Builds Beacon and packages it into a macOS .app bundle, then zips it.
# Unlike run-app.sh this does not launch the app — it is meant for CI/release.
# Usage: Scripts/package-app.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

VERSION="${1:-1.0.0}"
CONFIG="release"
BUILD_NAME="Beacon"          # SPM product (binary) name
APP_NAME="Beacon"             # user-facing app + bundle name
APP_DIR="${ROOT}/${APP_NAME}.app"
DIST_DIR="${ROOT}/dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}.app.zip"

echo "Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "Assembling ${APP_NAME}.app (version ${VERSION})..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Executable (renamed to the user-facing app name).
cp "${BIN_PATH}/${BUILD_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Bundled resources (xray + tun2socks binaries live in the SPM resource bundle).
BUNDLE="${BIN_PATH}/${BUILD_NAME}_${BUILD_NAME}.bundle"
if [ -d "${BUNDLE}" ]; then
  cp -R "${BUNDLE}" "${APP_DIR}/Contents/Resources/"
fi

# App icon, if present.
ICON_LINE=""
if [ -f "${ROOT}/Resources/AppIcon.icns" ]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
  ICON_LINE="  <key>CFBundleIconFile</key><string>AppIcon</string>"
fi

# Info.plist (LSUIElement=false so it shows in the Dock with a window)
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>dev.local.beacon</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
${ICON_LINE}
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSCameraUsageDescription</key><string>Beacon uses the camera to scan server QR codes.</string>
  <key>LSUIElement</key><false/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the app and the bundled binaries run locally.
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "Zipping..."
mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"
# ditto preserves bundle structure + resource forks for a valid macOS app zip.
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

echo "Done."
echo "App bundle: ${APP_DIR}"
echo "Zip:        ${ZIP_PATH}"
