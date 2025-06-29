# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial `CHANGELOG.md` file
- Comprehensive README.md documentation with detailed technical deep dive
- Debug logging throughout recording pipeline for troubleshooting

### Changed
- Streamlined for MVP by temporarily removing input tracking (mouse/keyboard) features
- Improved video recording initialization and error handling
- Enhanced logging for video frame delivery diagnostics
- Refactored CaptureSessionManager for improved stream handling

### Fixed
- Fixed missing video output by retaining SCStreamFrameOutput reference
- Fixed recording stop button flow and cleanup processes
- Improved recording state management and cleanup on stop
- Enhanced error recovery mechanisms in video processing

### Removed
- Temporarily disabled mouse and keyboard tracking UI elements for MVP focus
- Removed input tracking logic from RecordingManager for streamlined operation
