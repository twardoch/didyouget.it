# Changelog

All notable changes to Did You Get It will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure and build configuration
- Basic SwiftUI application with menu bar interface
- Core recording manager architecture
- Preferences system for app settings
- Screen recording permission handling
- README documentation
- Technical specification (SPEC.md)
- Implementation progress tracking (PROGRESS.md)
- Screen recording functionality with 60 FPS Retina support
- ScreenCaptureKit integration for modern macOS screen capture
- Multi-monitor support with display selection
- Window capture mode for specific applications
- H.264 video encoding with hardware acceleration
- Real-time video capture and compression pipeline
- Recording controls (start/stop/pause/resume)
- Recording timer with live duration display
- Screen/window selection UI in main interface

### Changed
- Updated .gitignore for Swift/macOS development
- Minimum macOS version set to 13.0 for MenuBarExtra API
- Enhanced RecordingManager with full screen capture implementation

### Planned
- Audio recording from selectable devices
- Mouse movement and click tracking with tap/hold-release detection
- Keyboard input recording in JSON format with tap/hold-release events
- Area selection for recording specific screen regions
- File output with configurable quality presets
- Keyboard shortcuts for recording control
- Error notifications and success confirmations
- Recording countdown timer

## [0.1.0] - TBD

Initial release with core functionality planned.

[Unreleased]: https://github.com/twardoch/didyouget.it/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/twardoch/didyouget.it/releases/tag/v0.1.0