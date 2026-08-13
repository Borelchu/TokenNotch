#!/bin/bash
# Builds NotchUsage as a release binary, wraps it in an .app bundle,
# and (optionally) registers it to start at login.
#
#   ./install.sh              # build + create dist/NotchUsage.app
#   ./install.sh --autostart  # also install a LaunchAgent for login start
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NotchUsage"
DIST="dist/$APP_NAME.app"

echo "▸ swift build -c release"
swift build -c release

echo "▸ bundling $DIST"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS"
cp ".build/release/$APP_NAME" "$DIST/Contents/MacOS/$APP_NAME"

cat > "$DIST/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>NotchUsage</string>
    <key>CFBundleIdentifier</key><string>local.notchusage</string>
    <key>CFBundleName</key><string>NotchUsage</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign -s - --force "$DIST" 2>/dev/null || true
echo "✓ $DIST 생성 완료 — open dist/$APP_NAME.app 으로 실행"

if [[ "${1:-}" == "--autostart" ]]; then
    PLIST_PATH="$HOME/Library/LaunchAgents/local.notchusage.plist"
    APP_BIN="$(pwd)/$DIST/Contents/MacOS/$APP_NAME"
    cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>local.notchusage</string>
    <key>ProgramArguments</key>
    <array><string>$APP_BIN</string></array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
</dict>
</plist>
PLIST
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH"
    echo "✓ 로그인 시 자동 실행 등록 완료 ($PLIST_PATH)"
fi
