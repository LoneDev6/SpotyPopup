#!/bin/bash
set -e

echo "🔨 Building SpotifydUI..."

# Build the executable
swift build -c release

# Create app bundle structure
APP_NAME="SpotifydUI.app"
BUNDLE_DIR="$APP_NAME/Contents"
MACOS_DIR="$BUNDLE_DIR/MacOS"

rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"

# Copy executable
cp .build/release/SpotifydUI "$MACOS_DIR/"

# Create Info.plist
cat > "$BUNDLE_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>SpotifydUI</string>
    <key>CFBundleIdentifier</key>
    <string>com.spotifydui.app</string>
    <key>CFBundleName</key>
    <string>SpotifydUI</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.spotifydui.auth</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>spotifydui</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "✅ App bundle created: $APP_NAME"
echo ""
echo "To run: open $APP_NAME"
