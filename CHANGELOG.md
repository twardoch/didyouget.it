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
- Audio recording functionality with microphone permission handling
- Audio device selection UI in preferences
- Audio capture with AAC encoding
- Audio/video synchronization
- AudioManager for device enumeration and configuration
- Mouse movement and click tracking with tap/hold-release detection
- Keyboard stroke recording in JSON format with tap/hold-release events
- Accessibility permission handling for input tracking
- JSON export for mouse movements, clicks, and drag events
- JSON export for keyboard events with modifier key tracking
- Privacy masking for sensitive keyboard input
- Basic area selection functionality with display and area dimensions
- Enhanced visual feedback in UI for area selection confirmation
- Animated area selection status indicators
- Improved error handling and validation for recording parameters
- Option to mix audio with video or save it separately
- Input device detection for audio, mouse, and keyboard tracking

### Changed
- Updated .gitignore for Swift/macOS development
- Fixed critical crash in recording engine during sample buffer processing
- Redesigned sample buffer handling to use proper MainActor isolation
- Fixed thread synchronization issues across the recording pipeline
- Added detailed diagnostics and frame/sample counting to monitor capture
- Fixed critical issues with zero-length video output files
- Added proper validation for sample buffer integrity
- Improved AVAssetWriter configuration and error handling
- Redesigned the capture session startup and teardown for more reliability
- Added validation checks for recording state transitions
- Minimum macOS version set to 13.0 for MenuBarExtra API
- Enhanced RecordingManager with full screen capture implementation
- Redesigned UI to be more compact and thoughtfully organized
- Improved color scheme and visual hierarchy for better user experience
- Enhanced button styles for more modern appearance
- Fixed "Select Area..." button to only appear when area capture is selected
- Added validation to prevent recording errors when parameters are missing
- Updated preferences button to properly open Settings window
- Fixed concurrency issues in mouse and keyboard tracking components
- Streamlined UI by removing unnecessary elements and improving tab controls
- Eliminated confusing icon/text tab combinations for a more consistent interface
- Removed redundant "Capture Type" label for cleaner appearance
- Removed potentially confusing circular icon from recording status area
- Fixed critical issue with empty .mov files during recording
- Added extensive logging throughout the recording process for better diagnostics
- Enhanced video and audio writer initialization and configuration with better error handling
- Fixed issues with input tracking JSON files not being created correctly
- Added comprehensive file verification checks after recording completes
- Improved error handling and reporting in sample buffer processing components
- Added frame and audio sample diagnostics for monitoring recording quality
- Improved error feedback throughout the recording pipeline
- Enhanced URL creation for recording files with better validation
- Fixed preferences access issues during recording session setup
- Added more robust bitrate and quality settings based on selected preferences
- Improved handling of video dimensions for Retina displays

### Planned
- Full featured area selection tool with visual selection interface
- Advanced file output with additional configurable quality presets
- Recording countdown timer before starting capture
- Audio level visualization for input monitoring
- Enhanced file organization with custom naming templates
- Mouse cursor overlay visualization in recordings
- Data synchronization with video timestamps for analysis
- Crash recovery for interrupted recordings
- Enhanced keyboard shortcut management
- Additional platform support (potentially iOS companion app)

## [0.1.0] - TBD

Initial release with core functionality planned.

[Unreleased]: https://github.com/twardoch/didyouget.it/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/twardoch/didyouget.it/releases/tag/v0.1.0