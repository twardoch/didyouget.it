# 9. Development & Contributing

## Development Environment Setup

### Prerequisites

#### Required Tools and Dependencies
```bash
# Install Xcode (latest version)
xcode-select --install

# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install development dependencies
brew install git swift-format swiftlint xcbeautify
brew install --cask sf-symbols

# Install optional tools for advanced development
brew install ffmpeg imagemagick jq
pip3 install pre-commit black isort
```

#### Swift and Xcode Setup
```bash
# Verify Swift version (should be 5.9+)
swift --version

# Check Xcode version
xcodebuild -version

# Install Xcode command line tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Project Structure

#### Repository Organization
```
DidYouGetIt-Mac/
├── DidYouGet/                    # Main application source
│   ├── DidYouGet/               # App bundle
│   │   ├── DidYouGetApp.swift   # App entry point
│   │   ├── Models/              # Data models and business logic
│   │   │   ├── Recording/       # Recording engine
│   │   │   └── InputTracking/   # Input tracking system
│   │   ├── Views/               # SwiftUI views
│   │   ├── Utilities/           # Helper utilities
│   │   └── Protocols/           # Protocol definitions
├── Tests/                       # Test suite
│   ├── DidYouGetTests/         # Unit tests
│   └── UITests/                # UI automation tests
├── Tools/                       # Development tools
│   ├── Scripts/                # Build and utility scripts
│   └── Configurations/         # Project configurations
├── Documentation/              # Additional documentation
├── Makefile                    # Build automation
├── Package.swift              # Swift Package Manager
└── src_docs/                  # MkDocs documentation source
```

#### Core Architecture Components
```swift
// Main architectural components overview
protocol RecordingServiceProtocol {
    func startRecording(with configuration: RecordingConfiguration) async throws
    func stopRecording() async throws
    var isRecording: Bool { get }
}

// Dependency injection container
class ServiceContainer {
    static let shared = ServiceContainer()
    
    // Core services
    lazy var recordingManager: RecordingServiceProtocol = RecordingManager()
    lazy var audioProcessor: AudioProcessorProtocol = AudioProcessor()
    lazy var inputTracker: InputTrackerProtocol = InputTracker()
    lazy var fileManager: OutputFileManagerProtocol = OutputFileManager()
}

// Protocol-oriented design for testability
protocol VideoProcessorProtocol: Actor {
    func processFrame(_ imageBuffer: CVImageBuffer, timestamp: CMTime) async
    func configureEncoder(settings: VideoSettings) async throws
}
```

### Building from Source

#### Build Process
```bash
# Clone the repository
git clone https://github.com/twardoch/didyougetit-mac.git
cd didyougetit-mac

# Install pre-commit hooks
pre-commit install

# Build using Makefile
make build

# Or build with Xcode
xcodebuild -project DidYouGet.xcodeproj -scheme DidYouGet -configuration Release

# Run the application
./run.sh

# Build for distribution
make build-release
```

#### Build Configuration
```swift
// Build configurations in project settings
#if DEBUG
    let logLevel: Logger.Level = .debug
    let enablePerformanceMetrics = true
    let skipPermissionChecks = false
#else
    let logLevel: Logger.Level = .info
    let enablePerformanceMetrics = false
    let skipPermissionChecks = false
#endif

// Feature flags for development
struct FeatureFlags {
    static let experimentalAudioProcessing = false
    static let advancedInputTracking = true
    static let mlGestureRecognition = false
}
```

#### Makefile Targets
```makefile
# Available make targets
.PHONY: build test clean install format lint

build:
	xcodebuild -project DidYouGet.xcodeproj -scheme DidYouGet -configuration Debug

build-release:
	xcodebuild -project DidYouGet.xcodeproj -scheme DidYouGet -configuration Release -archivePath build/DidYouGet.xcarchive archive

test:
	xcodebuild test -project DidYouGet.xcodeproj -scheme DidYouGet -destination 'platform=macOS'

clean:
	xcodebuild clean -project DidYouGet.xcodeproj -scheme DidYouGet
	rm -rf build/

format:
	swift-format --in-place --recursive Sources/ Tests/

lint:
	swiftlint --config .swiftlint.yml

install: build-release
	cp -R build/DidYouGet.xcarchive/Products/Applications/DidYouGet.app /Applications/
```

## Testing Framework

### Unit Testing Structure

#### Test Organization
```swift
// Example unit test structure
import XCTest
@testable import DidYouGet

class RecordingManagerTests: XCTestCase {
    var recordingManager: RecordingManager!
    var mockAudioProcessor: MockAudioProcessor!
    var mockVideoProcessor: MockVideoProcessor!
    
    override func setUp() {
        super.setUp()
        mockAudioProcessor = MockAudioProcessor()
        mockVideoProcessor = MockVideoProcessor()
        recordingManager = RecordingManager(
            audioProcessor: mockAudioProcessor,
            videoProcessor: mockVideoProcessor
        )
    }
    
    override func tearDown() {
        recordingManager = nil
        mockAudioProcessor = nil
        mockVideoProcessor = nil
        super.tearDown()
    }
    
    func testStartRecording() async throws {
        // Given
        let configuration = RecordingConfiguration.defaultConfiguration
        
        // When
        try await recordingManager.startRecording(with: configuration)
        
        // Then
        XCTAssertTrue(recordingManager.isRecording)
        XCTAssertTrue(mockAudioProcessor.didStartProcessing)
        XCTAssertTrue(mockVideoProcessor.didStartProcessing)
    }
}
```

#### Mock Objects for Testing
```swift
// Mock implementations for testing
class MockAudioProcessor: AudioProcessorProtocol {
    var didStartProcessing = false
    var didStopProcessing = false
    var processedSamples: [CMSampleBuffer] = []
    
    func startProcessing(configuration: AudioConfiguration) async throws {
        didStartProcessing = true
    }
    
    func stopProcessing() async throws {
        didStopProcessing = true
    }
    
    func processAudioSample(_ sampleBuffer: CMSampleBuffer) async {
        processedSamples.append(sampleBuffer)
    }
}

class MockRecordingService: RecordingServiceProtocol {
    var isRecording = false
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var lastConfiguration: RecordingConfiguration?
    
    func startRecording(with configuration: RecordingConfiguration) async throws {
        startRecordingCalled = true
        lastConfiguration = configuration
        isRecording = true
    }
    
    func stopRecording() async throws {
        stopRecordingCalled = true
        isRecording = false
    }
}
```

### Integration Testing

#### UI Testing with XCTest
```swift
import XCTest

class DidYouGetUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app for testing
        app.launchEnvironment["UITEST_MODE"] = "1"
        app.launchEnvironment["SKIP_PERMISSIONS"] = "1"
        app.launch()
    }
    
    func testRecordingWorkflow() throws {
        // Test complete recording workflow
        let recordButton = app.buttons["Record"]
        XCTAssertTrue(recordButton.exists)
        
        // Start recording
        recordButton.tap()
        
        // Verify recording indicator appears
        let recordingIndicator = app.staticTexts["Recording"]
        XCTAssertTrue(recordingIndicator.waitForExistence(timeout: 2.0))
        
        // Wait a moment then stop
        sleep(3)
        recordButton.tap()
        
        // Verify recording stopped
        XCTAssertFalse(recordingIndicator.exists)
        
        // Check that files were created
        // This would require additional helper functions to verify file system
    }
    
    func testPreferencesConfiguration() throws {
        // Open preferences
        app.menuBarItems["Did You Get It"].click()
        app.menuItems["Preferences"].click()
        
        let preferencesWindow = app.windows["Preferences"]
        XCTAssertTrue(preferencesWindow.waitForExistence(timeout: 2.0))
        
        // Test frame rate selection
        let frameRatePopup = preferencesWindow.popUpButtons["Frame Rate"]
        frameRatePopup.click()
        frameRatePopup.menuItems["30 FPS"].click()
        
        // Verify setting was saved
        XCTAssertEqual(frameRatePopup.value as? String, "30 FPS")
    }
}
```

#### Performance Testing
```swift
class PerformanceTests: XCTestCase {
    func testRecordingPerformance() throws {
        let recordingManager = RecordingManager()
        let configuration = RecordingConfiguration.defaultConfiguration
        
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "Recording completes")
            
            Task {
                do {
                    try await recordingManager.startRecording(with: configuration)
                    try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    try await recordingManager.stopRecording()
                    expectation.fulfill()
                } catch {
                    XCTFail("Recording failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testFrameProcessingPerformance() throws {
        let videoProcessor = VideoProcessor()
        let testImageBuffer = createTestImageBuffer()
        
        measure {
            Task {
                for i in 0..<100 {
                    let timestamp = CMTime(value: Int64(i), timescale: 60)
                    await videoProcessor.processFrame(testImageBuffer, timestamp: timestamp)
                }
            }
        }
    }
}
```

## Code Quality and Standards

### Coding Standards

#### Swift Style Guide
```swift
// Follow Swift API Design Guidelines and project-specific standards

// MARK: - Good Examples

// Protocol naming: use -able, -ible suffixes or descriptive nouns
protocol Recordable {
    func startRecording() async throws
}

protocol RecordingDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop(withFiles files: [URL])
}

// Type naming: Use clear, descriptive names
struct RecordingConfiguration {
    let frameRate: Int
    let resolution: Resolution
    let audioSettings: AudioSettings
}

// Function naming: Start with verb, be descriptive
func startRecording(with configuration: RecordingConfiguration) async throws {
    // Implementation
}

// Variable naming: Use descriptive names, avoid abbreviations
private var recordingDuration: TimeInterval = 0
private var isCurrentlyRecording = false

// MARK: - Code Organization

class RecordingManager {
    // MARK: - Properties
    private let audioProcessor: AudioProcessorProtocol
    private let videoProcessor: VideoProcessorProtocol
    
    // MARK: - Initialization
    init(audioProcessor: AudioProcessorProtocol, videoProcessor: VideoProcessorProtocol) {
        self.audioProcessor = audioProcessor
        self.videoProcessor = videoProcessor
    }
    
    // MARK: - Public Methods
    func startRecording(with configuration: RecordingConfiguration) async throws {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func configureRecordingSession() {
        // Implementation
    }
}
```

#### Documentation Standards
```swift
/// Manages video recording sessions with high-performance capture and processing.
///
/// The `RecordingManager` coordinates between video capture, audio processing, and input tracking
/// to create comprehensive recording sessions. It provides async/await APIs for all recording
/// operations and maintains thread safety through Swift's actor model.
///
/// Example usage:
/// ```swift
/// let manager = RecordingManager()
/// let config = RecordingConfiguration(frameRate: 60, resolution: .native)
/// try await manager.startRecording(with: config)
/// // ... perform actions to record
/// try await manager.stopRecording()
/// ```
class RecordingManager {
    
    /// Starts a new recording session with the specified configuration.
    ///
    /// - Parameter configuration: The recording configuration including video settings,
    ///   audio settings, and input tracking options.
    /// - Throws: `RecordingError.permissionDenied` if required permissions are not granted.
    /// - Throws: `RecordingError.insufficientDiskSpace` if there's not enough storage.
    /// - Throws: `RecordingError.alreadyRecording` if a recording session is already active.
    func startRecording(with configuration: RecordingConfiguration) async throws {
        // Implementation
    }
}
```

### Code Review Process

#### Pre-Commit Hooks
```bash
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: swift-format
        name: swift-format
        entry: swift-format
        language: system
        args: [--in-place]
        files: \.swift$
        
      - id: swiftlint
        name: SwiftLint
        entry: swiftlint
        language: system
        args: [--strict]
        files: \.swift$
        
      - id: tests
        name: Run Tests
        entry: make test
        language: system
        pass_filenames: false
        always_run: true
```

#### Code Review Checklist
- [ ] **Functionality**: Does the code work as intended?
- [ ] **Performance**: Are there any performance implications?
- [ ] **Memory Management**: Proper memory management and no leaks?
- [ ] **Thread Safety**: Proper use of actors/async-await for concurrency?
- [ ] **Error Handling**: Comprehensive error handling with meaningful messages?
- [ ] **Testing**: Adequate unit test coverage for new functionality?
- [ ] **Documentation**: Clear documentation for public APIs?
- [ ] **Style**: Follows project coding standards and Swift conventions?

## Contributing Guidelines

### Getting Started with Contributions

#### First-Time Contributors
1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
```bash
git clone https://github.com/your-username/didyougetit-mac.git
cd didyougetit-mac
```

3. **Set up the development environment**:
```bash
make setup-dev
```

4. **Create a feature branch**:
```bash
git checkout -b feature/your-feature-name
```

5. **Make your changes** following the coding standards
6. **Run tests** to ensure nothing is broken:
```bash
make test
```

7. **Commit your changes** with descriptive messages:
```bash
git commit -m "feat: add support for custom recording areas

- Implement interactive area selection
- Add coordinate validation
- Update UI for area configuration
- Add unit tests for area selection logic"
```

#### Contribution Types

**Bug Fixes:**
- Include steps to reproduce the bug
- Add regression tests
- Update documentation if needed

**New Features:**
- Discuss the feature in an issue first
- Include comprehensive tests
- Update documentation and examples
- Consider performance implications

**Documentation:**
- Fix typos and improve clarity
- Add examples and use cases
- Update API documentation
- Improve setup instructions

### Pull Request Process

#### PR Template
```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that causes existing functionality to change)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance impact assessed

## Screenshots/Recordings
Include screenshots or recordings demonstrating the changes (if applicable).

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes (or marked as breaking)
```

#### Review Process
1. **Automated Checks**: CI/CD pipeline runs tests and linting
2. **Code Review**: At least one maintainer reviews the code
3. **Testing**: Manual testing by reviewers if needed
4. **Documentation**: Verify documentation is updated
5. **Approval**: PR approved by maintainer
6. **Merge**: Squash and merge to main branch

### Development Workflow

#### Git Workflow
```bash
# Keep your fork updated
git remote add upstream https://github.com/twardoch/didyougetit-mac.git
git fetch upstream
git checkout main
git merge upstream/main

# Create feature branch
git checkout -b feature/new-audio-filter

# Make changes and commit
git add .
git commit -m "feat: implement noise reduction audio filter"

# Push to your fork
git push origin feature/new-audio-filter

# Create pull request on GitHub
```

#### Continuous Integration

#### GitHub Actions Workflow
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    
    - name: Cache Swift packages
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift') }}
    
    - name: Install dependencies
      run: |
        brew install swiftlint swift-format
    
    - name: Lint code
      run: swiftlint --strict
    
    - name: Format check
      run: swift-format --lint --recursive Sources/ Tests/
    
    - name: Build
      run: make build
    
    - name: Run tests
      run: make test
    
    - name: Build release
      if: github.ref == 'refs/heads/main'
      run: make build-release
    
    - name: Upload artifacts
      if: github.ref == 'refs/heads/main'
      uses: actions/upload-artifact@v3
      with:
        name: DidYouGetIt-Release
        path: build/DidYouGet.app
```

### Release Process

#### Version Management
```swift
// Version.swift - Centralized version management
struct AppVersion {
    static let major = 1
    static let minor = 0
    static let patch = 0
    static let build = 1
    
    static var versionString: String {
        return "\(major).\(minor).\(patch)"
    }
    
    static var fullVersionString: String {
        return "\(versionString) (\(build))"
    }
}
```

#### Release Checklist
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Version number incremented
- [ ] Changelog updated
- [ ] Performance benchmarks run
- [ ] Manual testing on different macOS versions
- [ ] Code signing and notarization completed
- [ ] Release notes prepared

#### Automated Release
```bash
# scripts/release.sh
#!/bin/bash

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

echo "Preparing release $VERSION..."

# Update version in code
sed -i '' "s/static let patch = .*/static let patch = ${VERSION##*.}/" Sources/DidYouGet/Version.swift

# Build release
make build-release

# Create release archive
cd build
zip -r "DidYouGetIt-${VERSION}.zip" DidYouGet.app

# Create GitHub release
gh release create "v${VERSION}" \
    "DidYouGetIt-${VERSION}.zip" \
    --title "Did You Get It v${VERSION}" \
    --notes-file ../CHANGELOG.md
```

This completes the comprehensive 9-chapter documentation for Did You Get It. The documentation covers everything from basic usage to advanced development topics, providing users and contributors with complete information about the application.