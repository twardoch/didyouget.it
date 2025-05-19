.PHONY: all build run test clean release install

# App configuration
APP_NAME = DidYouGet
BUNDLE_ID = it.didyouget.mac
PLATFORM = macosx
MIN_VERSION = 12.0

# Paths
BUILD_DIR = build
RELEASE_DIR = release
APP_PATH = $(BUILD_DIR)/$(APP_NAME).app

# Build flags
SWIFT_FLAGS = -c release
XCODE_FLAGS = -scheme $(APP_NAME) -configuration Release

all: build

build:
	@echo "Building $(APP_NAME)..."
	swift build $(SWIFT_FLAGS)

xcode-build:
	@echo "Building with Xcode..."
	xcodebuild -project $(APP_NAME).xcodeproj $(XCODE_FLAGS) -derivedDataPath $(BUILD_DIR)

run:
	@echo "Running $(APP_NAME)..."
	swift run

test:
	@echo "Running tests..."
	swift test

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf .build
	swift package clean

release: clean xcode-build
	@echo "Creating release build..."
	mkdir -p $(RELEASE_DIR)
	cp -R $(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app $(RELEASE_DIR)/
	@echo "Signing app..."
	codesign --deep --force --verify --verbose --sign "Developer ID Application" $(RELEASE_DIR)/$(APP_NAME).app
	@echo "Creating DMG..."
	create-dmg --volname "$(APP_NAME)" --window-size 400 300 --app-drop-link 250 150 --icon "$(APP_NAME).app" 150 150 $(RELEASE_DIR)/$(APP_NAME).dmg $(RELEASE_DIR)/$(APP_NAME).app

install: build
	@echo "Installing $(APP_NAME) to Applications..."
	cp -R $(APP_PATH) /Applications/

format:
	@echo "Formatting Swift code..."
	swift-format format -i -r DidYouGet/

lint:
	@echo "Linting Swift code..."
	swiftlint

setup:
	@echo "Setting up development environment..."
	@echo "Installing SwiftLint..."
	brew install swiftlint
	@echo "Installing swift-format..."
	brew install swift-format
	@echo "Installing create-dmg..."
	brew install create-dmg
	@echo "Setup complete!"

.DEFAULT_GOAL := build