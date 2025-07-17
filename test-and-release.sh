#!/bin/bash

# test-and-release.sh - Complete test and release workflow
# Usage: ./test-and-release.sh [version]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if version is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.1.0"
    exit 1
fi

VERSION="$1"
VERSION_TAG="v$VERSION"

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Use semantic versioning (e.g., 1.1.0)"
    exit 1
fi

echo "🚀 Starting test and release workflow for version $VERSION"

# Check if we're on the main branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "⚠️  Warning: You're not on the main branch. Current branch: $CURRENT_BRANCH"
    read -p "Do you want to continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working directory is not clean. Please commit or stash changes."
    git status --short
    exit 1
fi

# Run full test suite
echo "🧪 Running full test suite..."
./build.sh debug --test --clean

# Check if tag already exists
if git tag -l | grep -q "^$VERSION_TAG$"; then
    echo "❌ Tag $VERSION_TAG already exists"
    exit 1
fi

# Build release version
echo "📦 Building release version..."
./build.sh release --test

# Create and push tag
echo "🏷️  Creating tag $VERSION_TAG..."
git tag -a "$VERSION_TAG" -m "Release version $VERSION"

echo "📤 Pushing tag to origin..."
git push origin "$VERSION_TAG"

echo "✅ Release workflow complete!"
echo "   Version: $VERSION"
echo "   Tag: $VERSION_TAG"
echo "   Release package: release/DidYouGet-$VERSION-macos.tar.gz"

# Check for GitHub CLI and create release
if command -v gh &> /dev/null; then
    echo "🐙 GitHub CLI detected. Creating GitHub release..."
    
    # Create release notes
    RELEASE_NOTES="Release $VERSION

## Changes
$(git log --pretty=format:"- %s" $(git describe --tags --abbrev=0 HEAD^)..HEAD)

## Installation
Download the \`DidYouGet-$VERSION-macos.tar.gz\` file, extract it, and run the executable.

## Requirements
- macOS 13.0 or later"
    
    gh release create "$VERSION_TAG" \
        --title "Release $VERSION" \
        --notes "$RELEASE_NOTES" \
        "release/DidYouGet-$VERSION-macos.tar.gz"
    
    echo "✅ GitHub release created!"
else
    echo "ℹ️  GitHub CLI not found. Please create the release manually on GitHub."
fi

echo "🎉 All done!"