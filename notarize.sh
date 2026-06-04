#!/bin/zsh
# HermesControl notarization — requires a Developer ID Application cert + Apple Developer account.
# First time:  ./notarize.sh --store-credentials
# After that:  ./notarize.sh
set -e
cd "$(dirname "$0")"

APP_NAME="HermesControl"
APP="${APP_NAME}.app"
KEYCHAIN_PROFILE="${APP_NAME}-notarize"
# Team ID auto-detected from the cert name's (XXXXXXXXXX). Override: TEAM_ID=XXXX ./notarize.sh
TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
  | grep 'Developer ID Application' | head -1 | grep -oE '\([A-Z0-9]{10}\)' | tr -d '()')}"

store_credentials() {
  [[ -z "$TEAM_ID" ]] && { echo "✗ Could not detect Team ID — set TEAM_ID=XXXX"; exit 1; }
  echo "Storing credentials in the local Keychain (not iCloud)."
  echo "Enter your Apple ID + an app-specific password (appleid.apple.com > Security)."
  echo "Run this from Terminal.app (interactive input required)."
  xcrun notarytool store-credentials "$KEYCHAIN_PROFILE" --team-id "$TEAM_ID"
}

notarize() {
  ./build.sh
  rm -f "${APP_NAME}.zip" "${APP_NAME}-notarized.zip"
  ditto -c -k --keepParent "$APP" "${APP_NAME}.zip"
  echo "→ Submitting for notarization (1-5 min)…"
  xcrun notarytool submit "${APP_NAME}.zip" --keychain-profile "$KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP"
  rm -f "${APP_NAME}.zip"
  ditto -c -k --keepParent "$APP" "${APP_NAME}-notarized.zip"
  echo "✓ ${APP_NAME}-notarized.zip — attach this to the GitHub Release"
  spctl -a -vvv "$APP" 2>&1 | head -3
}

case "${1}" in
  --store-credentials) store_credentials ;;
  "") notarize ;;
  *) echo "Usage: $0 [--store-credentials]"; exit 1 ;;
esac
