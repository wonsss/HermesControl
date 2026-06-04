#!/bin/zsh
# DMG 생성 스크립트 — notarized .app → drag-install DMG
# Requires: brew install create-dmg
# Usage: ./scripts/create-dmg.sh [--skip-notarize]
set -e
cd "$(dirname "$0")/.."

APP_NAME="HermesControl"
VERSION="1.0.0"
APP="${APP_NAME}.app"
DMG="${APP_NAME}-${VERSION}.dmg"

if [[ "${1}" != "--skip-notarize" ]]; then
  echo "→ Building + notarizing…"
  ./notarize.sh
fi

if ! command -v create-dmg &>/dev/null; then
  echo "✗ create-dmg not found. Install: brew install create-dmg"; exit 1
fi

echo "→ Creating DMG…"
rm -f "$DMG"
create-dmg \
  --volname "${APP_NAME}" \
  --volicon "${APP_NAME}.icns" \
  --window-pos 200 120 \
  --window-size 600 380 \
  --icon-size 100 \
  --icon "${APP}" 160 185 \
  --hide-extension "${APP}" \
  --app-drop-link 430 185 \
  --no-internet-enable \
  "$DMG" \
  "$APP"

# Sign the DMG itself
DEV_ID_HASH=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | awk '{print $2}' || true)
if [[ -n "$DEV_ID_HASH" ]]; then
  codesign --force --sign "$DEV_ID_HASH" "$DMG"
  echo "→ DMG signed"

  KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-hermescontrol-notarize}"
  if xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    echo "→ Submitting DMG for notarization…"
    xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait
    xcrun stapler staple "$DMG"
    echo "✓ DMG notarized: $DMG"
  else
    echo "⚠ No keychain profile found. DMG created but not notarized."
    echo "  Run: ./notarize.sh --store-credentials  then  ./scripts/create-dmg.sh --skip-notarize"
  fi
fi

echo "✓ $DMG ($(du -sh "$DMG" | awk '{print $1}'))"
