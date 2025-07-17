#!/bin/bash

# install.sh - Install DidYouGet to Applications folder
# Usage: ./install.sh [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="DidYouGet"
INSTALL_DIR="/Applications"
FORCE_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

echo "📦 Installing $APP_NAME"

# Check if already installed
if [ -d "$INSTALL_DIR/$APP_NAME.app" ] && [ "$FORCE_INSTALL" = false ]; then
    echo "⚠️  $APP_NAME is already installed in $INSTALL_DIR"
    read -p "Overwrite existing installation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 1
    fi
fi

# Build release version
echo "🔨 Building release version..."
./build.sh release --test

# Get version info
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
VERSION_CLEAN=$(echo "$VERSION" | sed 's/^v//')

# Create app bundle structure
APP_BUNDLE="$SCRIPT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📁 Creating app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>it.didyouget.mac</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$VERSION_CLEAN</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION_CLEAN</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Copy to Applications (requires admin privileges)
echo "📥 Installing to $INSTALL_DIR..."
if [ -w "$INSTALL_DIR" ]; then
    # Can write directly
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
else
    # Need sudo
    sudo rm -rf "$INSTALL_DIR/$APP_NAME.app"
    sudo cp -R "$APP_BUNDLE" "$INSTALL_DIR/"
fi

# Verify installation
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "✅ $APP_NAME installed successfully!"
    echo "   Location: $INSTALL_DIR/$APP_NAME.app"
    echo "   Version: $VERSION_CLEAN"
    echo ""
    echo "🚀 You can now launch $APP_NAME from:"
    echo "   - Applications folder"
    echo "   - Spotlight search"
    echo "   - Command line: open -a $APP_NAME"
else
    echo "❌ Installation failed"
    exit 1
fi

echo "🎉 Installation complete!"