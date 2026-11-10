#!/bin/bash
# bundle.sh: release build, assembled into build/Scrubby.app and ad-hoc signed.
#
# Ad-hoc signing gives every build a new identity, so macOS forgets the
# Accessibility grant on each rebuild: toggle Scrubby off and on in
# System Settings › Privacy & Security › Accessibility afterwards.
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/Scrubby.app"
BIN=".build/release/Scrubby"

swift build -c release

rm -rf "$APP" build/Scrubby.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Scrubby"

"$BIN" --write-iconset build/Scrubby.iconset
iconutil -c icns build/Scrubby.iconset -o "$APP/Contents/Resources/Scrubby.icns"

# Never change CFBundleIdentifier: the Accessibility grant hangs off it.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Scrubby</string>
    <key>CFBundleIdentifier</key>
    <string>sh.micky.scrubby</string>
    <key>CFBundleName</key>
    <string>Scrubby</string>
    <key>CFBundleDisplayName</key>
    <string>Scrubby</string>
    <key>CFBundleIconFile</key>
    <string>Scrubby</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
codesign --verify --strict "$APP"

echo "Built:   $APP (build ${BUILD})"
echo "Try it:  open $APP"
echo "Install: scripts/install.sh"
