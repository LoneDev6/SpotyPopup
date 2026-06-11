#!/bin/bash
set -e

echo "🛑 Killing existing SpotyPopup processes..."
pkill -f SpotyPopup || true

echo "🔨 Building SpotyPopup..."

# Build the executable
swift build -c release

# Create app bundle structure
APP_NAME="SpotyPopup.app"
BUNDLE_DIR="$APP_NAME/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Resources"

rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/SpotyPopup "$MACOS_DIR/"
chmod +x "$MACOS_DIR/SpotyPopup"

# Copy icons
cp Resources/AppIcon.icns "$RESOURCES_DIR/"
cp Resources/AppIcon_login.png "$RESOURCES_DIR/"

# Create Info.plist
cat > "$BUNDLE_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SpotyPopup</string>
    <key>CFBundleIdentifier</key>
    <string>com.spotypopup.app</string>
    <key>CFBundleName</key>
    <string>SpotyPopup</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.spotypopup.auth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>spotypopup</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "✅ App bundle created: $APP_NAME"
echo ""
echo "🔏 Signing app bundle..."
codesign --force --deep --sign - --options runtime "$APP_NAME"
echo ""
echo "🚀 Starting SpotyPopup..."
open "$APP_NAME"
