#!/bin/bash

# run.sh - Build and run Did You Get It app
# Usage: ./run.sh [debug|release]

set -e

# Default to debug build
BUILD_TYPE=${1:-debug}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if the directory structure exists
if [ ! -d "DidYouGet/DidYouGet" ]; then
    echo "Error: DidYouGet directory structure not found."
    exit 1
fi

echo "Building Did You Get It app in $BUILD_TYPE mode..."

if [ "$BUILD_TYPE" = "release" ]; then
    # Release build
    swift build -c release
    APP_PATH="$(swift build -c release --show-bin-path)/DidYouGet"
else
    # Debug build
    swift build
    APP_PATH="$(swift build --show-bin-path)/DidYouGet"
fi

# Check if build succeeded
if [ ! -f "$APP_PATH" ]; then
    echo "Error: Build failed. Could not find executable at $APP_PATH"
    exit 1
fi

echo "Build successful!"
echo "Running application from: $APP_PATH"

# Run the app
"$APP_PATH"