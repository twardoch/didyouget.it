# Build and Release Guide

This document describes how to build, test, and release the DidYouGet application.

## Prerequisites

- **macOS 13.0+** (required for building and running)
- **Swift 5.9+** (available through Xcode Command Line Tools)
- **Git** (for version management)

### Installing Swift

1. Install Xcode Command Line Tools:
   ```bash
   xcode-select --install
   ```

2. Or install full Xcode from the App Store

3. Verify Swift installation:
   ```bash
   swift --version
   ```

## Quick Start

### Building for Development

```bash
# Build debug version with tests
./build.sh debug --test

# Build without tests
./build.sh debug

# Clean build
./build.sh debug --clean
```

### Building for Release

```bash
# Build release version with tests
./build.sh release --test

# Build release version without tests
./build.sh release
```

### Running Tests

```bash
# Run tests only
swift test

# Run tests with build script
./build.sh debug --test
```

## Version Management

The application uses **semantic versioning** based on Git tags:

- Version numbers follow the format: `MAJOR.MINOR.PATCH`
- Git tags should be prefixed with `v` (e.g., `v1.2.3`)
- Development builds show `-dev` suffix with commit info
- Release builds show clean version numbers

### Version Information

The `VersionManager` class provides:
- `currentVersion`: Current version from git tags
- `isReleaseVersion`: Whether this is an exact tag match
- `buildNumber`: Git commit count
- `commitHash`: Short commit hash
- `fullVersionString`: Complete version with build info

## Build Scripts

### `build.sh`

Main build script with versioning support.

**Usage:**
```bash
./build.sh [debug|release] [--test] [--clean]
```

**Options:**
- `debug` (default): Build debug version
- `release`: Build optimized release version
- `--test`: Run test suite before building
- `--clean`: Clean build artifacts first

**Examples:**
```bash
./build.sh                      # Debug build
./build.sh release --test       # Release build with tests
./build.sh debug --clean --test # Clean debug build with tests
```

### `test-and-release.sh`

Complete workflow for creating tagged releases.

**Usage:**
```bash
./test-and-release.sh <version>
```

**Example:**
```bash
./test-and-release.sh 1.2.0
```

This script:
1. Validates version format
2. Checks working directory is clean
3. Runs full test suite
4. Creates release build
5. Creates and pushes git tag
6. Creates GitHub release (if GitHub CLI is available)

## Testing

### Test Structure

```
Tests/
├── DidYouGetTests/
│   ├── VersionManagerTests.swift
│   ├── PreferencesManagerTests.swift
│   ├── RecordingManagerTests.swift
│   └── AudioManagerTests.swift
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests with parallel execution
swift test --parallel

# Run specific test file
swift test --filter VersionManagerTests
```

### Test Coverage

The test suite covers:
- Version management and git tag integration
- Preferences management
- Recording state management
- Audio device management
- Core functionality validation

## Continuous Integration

### GitHub Actions Workflows

1. **CI (`ci.yml`)**
   - Triggers on push to main/develop branches and PRs
   - Runs tests and linting
   - Supports caching for faster builds

2. **Release (`release.yml`)**
   - Triggers on git tag pushes (`v*`)
   - Runs full test suite
   - Creates release builds
   - Publishes GitHub releases with binaries

3. **Multiplatform (`multiplatform.yml`)**
   - Builds for different architectures (x86_64, ARM64)
   - Creates universal binaries
   - Provides multiple download options

### Workflow Files

- `.github/workflows/ci.yml` - Continuous integration
- `.github/workflows/release.yml` - Release automation
- `.github/workflows/multiplatform.yml` - Multi-architecture builds

## Release Process

### Automated Release (Recommended)

1. Ensure all changes are committed and pushed
2. Run the release script:
   ```bash
   ./test-and-release.sh 1.2.0
   ```
3. The script will handle testing, tagging, and GitHub release creation

### Manual Release

1. Run tests: `./build.sh debug --test`
2. Create release build: `./build.sh release`
3. Create tag: `git tag -a v1.2.0 -m "Release 1.2.0"`
4. Push tag: `git push origin v1.2.0`
5. Create GitHub release manually

### Release Artifacts

Each release includes:
- **Universal binary** (`-universal.tar.gz`) - Recommended for all users
- **x86_64 binary** (`-x86_64.tar.gz`) - Intel Macs only
- **ARM64 binary** (`-arm64.tar.gz`) - Apple Silicon Macs only
- **Version file** - Build information

## Development Workflow

### Pre-commit Checklist

1. Run tests: `./build.sh debug --test`
2. Check formatting: `swift-format lint --recursive DidYouGet/`
3. Run linting: `swiftlint`
4. Ensure version manager integration works

### Code Quality

The project uses:
- **SwiftLint** for code style enforcement
- **swift-format** for consistent formatting
- **Unit tests** for functionality validation
- **Git hooks** for automated checks

### Configuration Files

- `.swiftlint.yml` - SwiftLint configuration
- `Package.swift` - Swift package configuration
- `Makefile` - Alternative build commands

## Troubleshooting

### Common Issues

1. **Swift not found**
   - Install Xcode Command Line Tools
   - Verify with `swift --version`

2. **Build failures**
   - Clean build artifacts: `./build.sh debug --clean`
   - Check Swift version compatibility

3. **Test failures**
   - Ensure screen recording permissions are granted
   - Check for required system dependencies

4. **Version issues**
   - Verify git tags are properly formatted (`v1.2.3`)
   - Check git repository is properly initialized

### Getting Help

- Check build logs for detailed error messages
- Review GitHub Actions logs for CI failures
- Ensure all prerequisites are installed
- Verify file permissions on build scripts

## Advanced Usage

### Custom Build Configuration

You can modify build settings in:
- `Package.swift` - Swift package configuration
- `build.sh` - Build script parameters
- `.github/workflows/` - CI/CD configuration

### Integration with Other Tools

The build system can be integrated with:
- IDEs (Xcode, VS Code)
- Package managers (Homebrew, MacPorts)
- Distribution systems (Mac App Store, direct download)

For more details, see the main project documentation.