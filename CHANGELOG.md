# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial `CHANGELOG.md` file
- Comprehensive README.md documentation with detailed technical deep dive
- Debug logging throughout recording pipeline for troubleshooting
- Complete MkDocs documentation infrastructure in `src_docs/`
- Protocol-based architecture for better testability
- Async/await support for frame processing
- Comprehensive error types with recovery suggestions
- Centralized logging infrastructure with categories and levels
- Singleton pattern implementation for managers
- Mock implementations for testing
- Protocol-based unit tests

### Changed
- Streamlined for MVP by temporarily removing input tracking (mouse/keyboard) features
- Improved video recording initialization and error handling
- Enhanced logging for video frame delivery diagnostics
- Refactored CaptureSessionManager for improved stream handling
- Migrated from callback-based to async/await patterns
- Replaced print statements with structured logging
- Improved error handling with specific error types
- Updated code to use protocol-based design patterns

### Fixed
- Fixed missing video output by retaining SCStreamFrameOutput reference
- Fixed recording stop button flow and cleanup processes
- Improved recording state management and cleanup on stop
- Enhanced error recovery mechanisms in video processing

### Removed
- Temporarily disabled mouse and keyboard tracking UI elements for MVP focus
- Removed input tracking logic from RecordingManager for streamlined operation
