#!/bin/bash
set -e

APP_NAME="NotchBox"
APP_BUNDLE="$APP_NAME.app"
BIN_DIR=".build/arm64-apple-macosx/debug" # Path might vary depending on arch, let's just use swift build

echo "Building project..."
swift build

echo "Creating App Bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Get the path to the built executable
EXECUTABLE_PATH=$(swift build --show-bin-path)/$APP_NAME

cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/"

# Create a basic Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/> <!-- Hides from Dock -->
    <key>NSAppleEventsUsageDescription</key>
    <string>This app requires access to Apple Events to control Music.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app requires access to your location to display local weather in the NotchBox.</string>
</dict>
</plist>
EOF

# Clear any extended attributes to prevent Gatekeeper errors locally
xattr -rc "$APP_BUNDLE"

# Apply an ad-hoc signature to the complete App Bundle (including the Info.plist)
echo "Code signing App Bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Running NotchBox..."
open "$APP_BUNDLE"
