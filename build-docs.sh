#!/bin/bash
# this_file: build-docs.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SRC_DOCS_DIR="src_docs"
BUILD_DIR="docs"
SITE_DIR="site"

echo -e "${GREEN}Building Did You Get It Documentation${NC}"
echo "========================================"

# Check if mkdocs is installed
if ! command -v mkdocs &> /dev/null; then
    echo -e "${YELLOW}MkDocs not found. Installing...${NC}"
    pip install mkdocs mkdocs-material mkdocstrings[python]
fi

# Clean previous builds
if [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning previous documentation build...${NC}"
    rm -rf "$BUILD_DIR"
fi

if [ -d "$SITE_DIR" ]; then
    rm -rf "$SITE_DIR"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Copy documentation files
echo -e "${GREEN}Copying documentation files...${NC}"
cp -r "$SRC_DOCS_DIR"/* "$BUILD_DIR/"

# Build the documentation
echo -e "${GREEN}Building documentation site...${NC}"
cd "$BUILD_DIR"
mkdocs build

# Move site to root
cd ..
if [ -d "$BUILD_DIR/site" ]; then
    mv "$BUILD_DIR/site" .
    echo -e "${GREEN}Documentation built successfully!${NC}"
    echo -e "View at: ${YELLOW}file://$(pwd)/site/index.html${NC}"
else
    echo -e "${RED}Documentation build failed!${NC}"
    exit 1
fi

# Optional: Serve locally
if [ "$1" = "--serve" ]; then
    echo -e "${GREEN}Starting documentation server...${NC}"
    cd "$BUILD_DIR"
    mkdocs serve
fi