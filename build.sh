#!/bin/zsh
set -e
cd "$(dirname "$0")"

echo "→ 아이콘 생성…"
swift generate_icon.swift
iconutil -c icns HermesControl.iconset -o HermesControl.icns
rm -rf HermesControl.iconset

echo "→ swift build (release)…"
swift build -c release
BIN=$(swift build -c release --show-bin-path)/HermesControl

APP="HermesControl.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/HermesControl"
cp HermesControl.icns "$APP/Contents/Resources/HermesControl.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>io.github.wonsss.hermescontrol</string>
    <key>CFBundleName</key>
    <string>HermesControl</string>
    <key>CFBundleExecutable</key>
    <string>HermesControl</string>
    <key>CFBundleIconFile</key>
    <string>HermesControl</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Sign with Developer ID + hardened runtime (required for notarization).
# Falls back to ad-hoc if no Developer ID cert is present (local dev only — not notarizable).
DEVID_HASH=$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')
if [ -n "$DEVID_HASH" ]; then
  codesign --force --deep --options runtime --timestamp --sign "$DEVID_HASH" "$APP"
  echo "✓ signed (Developer ID, hardened runtime): $DEVID_HASH"
else
  codesign --force --deep --sign - "$APP" 2>/dev/null || true
  echo "⚠ ad-hoc signed (no Developer ID cert — cannot be notarized)"
fi
echo "✓ built: $(pwd)/$APP"
echo ""
echo "Run:      open $(pwd)/$APP"
echo "Notarize: ./notarize.sh   (after build)"
