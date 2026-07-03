#!/usr/bin/env bash
# Builds Beacon and packages it into a proper macOS .app bundle so the
# SwiftUI window and Dock icon appear correctly, then launches it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

CONFIG="${1:-release}"
BUILD_NAME="XrayClient"      # SPM product (binary) name
APP_NAME="Beacon"             # user-facing app + bundle name
APP_DIR="${ROOT}/${APP_NAME}.app"

echo "Building (${CONFIG})..."
swift build -c "${CONFIG}"

BIN_PATH="$(swift build -c "${CONFIG}" --show-bin-path)"

echo "Assembling ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Executable (renamed to the user-facing app name).
cp "${BIN_PATH}/${BUILD_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Bundled resources (xray binary lives in the SPM resource bundle).
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
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
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

# Ad-hoc sign so the app and the bundled xray binary run locally.
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || true

echo "Launching ${APP_NAME}.app..."
open "${APP_DIR}"
echo "Done. App bundle at: ${APP_DIR}"
