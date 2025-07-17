#!/bin/bash

# build.sh - Build script with versioning support
# Usage: ./build.sh [debug|release] [--test] [--clean]

set -e

# Configuration
APP_NAME="DidYouGet"
BUNDLE_ID="it.didyouget.mac"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
RELEASE_DIR="$SCRIPT_DIR/release"

# Default options
BUILD_TYPE="debug"
RUN_TESTS=false
CLEAN_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        debug|release)
            BUILD_TYPE="$1"
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [debug|release] [--test] [--clean]"
            exit 1
            ;;
    esac
done

cd "$SCRIPT_DIR"

# Check if Swift is available
if ! command -v swift &> /dev/null; then
    echo "❌ Swift is not installed or not in PATH"
    echo "Please install Swift from https://swift.org/download/"
    exit 1
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$RELEASE_DIR"
    swift package clean
fi

# Get version information
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")
VERSION_CLEAN=$(echo "$VERSION" | sed 's/^v//')
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || echo "0")
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
IS_RELEASE=$(git describe --tags --exact-match HEAD 2>/dev/null && echo "true" || echo "false")

if [ "$IS_RELEASE" = "true" ]; then
    FULL_VERSION="$VERSION_CLEAN (build $BUILD_NUMBER)"
else
    FULL_VERSION="$VERSION_CLEAN-dev (build $BUILD_NUMBER, commit $COMMIT_HASH)"
fi

echo "📦 Building $APP_NAME"
echo "   Version: $FULL_VERSION"
echo "   Build Type: $BUILD_TYPE"
echo "   Run Tests: $RUN_TESTS"

# Run tests if requested
if [ "$RUN_TESTS" = true ]; then
    echo "🧪 Running tests..."
    swift test --parallel
    echo "✅ Tests passed!"
fi

# Build the application
echo "🔨 Building application..."
if [ "$BUILD_TYPE" = "release" ]; then
    swift build -c release
    APP_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
else
    swift build
    APP_PATH="$(swift build --show-bin-path)/$APP_NAME"
fi

# Verify build
if [ ! -f "$APP_PATH" ]; then
    echo "❌ Build failed. Could not find executable at $APP_PATH"
    exit 1
fi

echo "✅ Build successful!"
echo "   Executable: $APP_PATH"
echo "   Version: $FULL_VERSION"

# Create release package if building for release
if [ "$BUILD_TYPE" = "release" ]; then
    echo "📦 Creating release package..."
    mkdir -p "$RELEASE_DIR"
    
    # Copy executable
    cp "$APP_PATH" "$RELEASE_DIR/"
    
    # Create version info file
    cat > "$RELEASE_DIR/version.txt" << EOF
$APP_NAME $FULL_VERSION
Built: $(date)
Platform: macOS
EOF
    
    # Create archive
    cd "$RELEASE_DIR"
    tar -czf "$APP_NAME-$VERSION_CLEAN-macos.tar.gz" "$APP_NAME" version.txt
    
    echo "✅ Release package created: $RELEASE_DIR/$APP_NAME-$VERSION_CLEAN-macos.tar.gz"
fi

echo "🎉 Build complete!"