#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
APP="$ROOT/dist/CavalryToolbar_assets/CavalryWheel.app"
mkdir -p "$APP/Contents/MacOS"
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/CavalryWheelBuild.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT HUP INT TERM
cat "$ROOT/native/macos/UIDispatch.swift" "$ROOT/native/macos/CavalryWheel.swift" > "$BUILD_DIR/main.swift"
/usr/bin/xcrun swiftc -O -target arm64-apple-macos12.0 "$BUILD_DIR/main.swift" -framework AppKit -framework ApplicationServices -o "$BUILD_DIR/CavalryWheel-arm64"
/usr/bin/xcrun swiftc -O -target x86_64-apple-macos12.0 "$BUILD_DIR/main.swift" -framework AppKit -framework ApplicationServices -o "$BUILD_DIR/CavalryWheel-x86_64"
/usr/bin/lipo -create "$BUILD_DIR/CavalryWheel-arm64" "$BUILD_DIR/CavalryWheel-x86_64" -output "$APP/Contents/MacOS/CavalryWheel"
mkdir -p "$APP/Contents/Resources"
cp "$ROOT/native/macos/UIRelay.js" "$APP/Contents/Resources/UIRelay.js"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.cavalrytoolbar.wheel</string>
<key>CFBundleName</key><string>Cavalry Wheel</string>
<key>CFBundleExecutable</key><string>CavalryWheel</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>0.1.0</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>12.0</string>
</dict></plist>
PLIST
/usr/bin/codesign --force --sign - "$APP"
/usr/bin/lipo -info "$APP/Contents/MacOS/CavalryWheel"
printf '%s\n' "$APP"
