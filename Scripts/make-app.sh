#!/usr/bin/env bash
# Bundles the SwiftPM executable into a distributable Automations.app.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="Automations.app"
BIN="Automations"

echo "▸ Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$BIN"

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/$BIN"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Automations</string>
    <key>CFBundleDisplayName</key><string>Automations</string>
    <key>CFBundleExecutable</key><string>Automations</string>
    <key>CFBundleIdentifier</key><string>com.nolanselby.automations</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "✓ Built $APP"
echo "  open $APP"
