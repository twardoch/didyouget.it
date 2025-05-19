# Did You Get It - Technical Specification

## Overview

**Did You Get It** is a high-performance screen recording application for macOS that captures screen content, audio, mouse movements, and keyboard input with minimal UI overhead.

- **Application Name**: Did You Get It
- **Bundle Identifier**: it.didyouget.mac
- **Homepage**: https://didyouget.it
- **Platform**: macOS
- **Target macOS Version**: 12.0+ (Monterey and later)

## Core Requirements

### 1. Screen Recording
- **Frame Rate**: 60 FPS
- **Resolution**: Full Retina resolution support
- **Screen Selection**: User can select which screen to record (for multi-monitor setups)
- **Area Selection**: User can define a specific recording area on the selected screen
- **Format**: H.264/H.265 video codec with hardware acceleration

### 2. Audio Recording (Optional)
- **Device Selection**: User can select any available audio input device
- **Format**: AAC audio codec
- **Sync**: Audio must be perfectly synchronized with video
- **Mixing**: If enabled, audio should be mixed into the video file

### 3. Mouse Tracking (Optional)
- **Movement**: Record all mouse movements within the recording area
- **Clicks**: Capture left/right clicks with timestamps
- **Format**: JSON or custom lightweight format
- **Overlay**: Option to visualize mouse cursor in the video

### 4. Keyboard Recording (Optional)
- **Capture**: Record all keyboard strokes during recording
- **Format**: WebVTT format for compatibility
- **Privacy**: Ability to mask sensitive input (passwords)
- **Timestamps**: Precise timing synchronized with video

### 5. Output Management
- **File Format**: MP4 container for video/audio
- **Separate Files**: Option to save mouse/keyboard data separately
- **Compression**: Configurable quality settings
- **Location**: User-selectable save location

## User Interface Design

### Minimal UI Principle
- **Launch**: Simple menu bar icon or dock icon
- **Configuration**: Minimal preferences window
- **Recording Controls**: 
  - Start/Stop button (keyboard shortcut: ⌘⇧R)
  - Pause/Resume (keyboard shortcut: ⌘⇧P)
  - Area selection tool
- **Status Indication**: Subtle recording indicator

### Configuration Options
1. **Recording Settings**
   - Screen selection dropdown
   - Area selection (full screen or custom region)
   - Frame rate: 30/60 FPS
   - Quality preset: Low/Medium/High/Lossless

2. **Audio Settings**
   - Enable/Disable audio recording
   - Input device selection
   - Audio quality settings

3. **Input Tracking**
   - Enable/Disable mouse tracking
   - Enable/Disable keyboard tracking
   - Privacy options for keyboard input

4. **Output Settings**
   - Default save location
   - File naming convention
   - Automatic file organization

## Technical Architecture

### Core Technologies
- **Language**: Swift 6.0+
- **Framework**: AVFoundation for video/audio capture
- **Screen Capture**: CGWindowListCreateImage/ScreenCaptureKit
- **Mouse/Keyboard**: CGEventTap for system-wide event monitoring
- **UI Framework**: SwiftUI for minimal interface

### Key Components

1. **Screen Capture Engine**
   - Uses ScreenCaptureKit for efficient screen capture
   - Hardware-accelerated encoding
   - Real-time compression

2. **Audio Engine**
   - AVAudioEngine for audio capture
   - Real-time mixing capabilities
   - Synchronization with video timestamps

3. **Input Monitor**
   - CGEventTap for mouse/keyboard events
   - Efficient event filtering
   - Thread-safe event queuing

4. **File Writer**
   - AVAssetWriter for video/audio output
   - Concurrent writing for performance
   - Crash-resistant file handling

### Performance Considerations
- **CPU Usage**: < 10% during recording
- **Memory Usage**: < 200MB baseline
- **Disk I/O**: Buffered writing to minimize impact
- **GPU Usage**: Hardware acceleration for encoding

## Security & Privacy

### Permissions Required
1. Screen Recording permission
2. Microphone access (if audio enabled)
3. Accessibility permission (for keyboard/mouse tracking)

### Privacy Features
- No network connectivity required
- All processing done locally
- Optional keyboard input masking
- Clear permission requests

## File Formats

### Video Output
```
Container: MP4
Video Codec: H.264/H.265
Audio Codec: AAC (if enabled)
Frame Rate: 30/60 FPS
Resolution: Native display resolution
```

### Mouse Data Format (JSON)
```json
{
  "version": "1.0",
  "recording_start": "2024-01-01T00:00:00Z",
  "events": [
    {
      "timestamp": 0.0,
      "type": "move",
      "x": 100,
      "y": 200
    },
    {
      "timestamp": 1.5,
      "type": "click",
      "button": "left",
      "x": 150,
      "y": 250
    }
  ]
}
```

### Keyboard Data Format (WebVTT)
```
WEBVTT

00:00:00.000 --> 00:00:00.500
KEY: H

00:00:00.600 --> 00:00:01.100
KEY: e

00:00:01.200 --> 00:00:01.700
KEY: l

00:00:01.800 --> 00:00:02.300
KEY: l

00:00:02.400 --> 00:00:02.900
KEY: o
```

## Error Handling

### Recording Failures
- Graceful degradation if permissions denied
- Automatic recovery from temporary failures
- Clear error messages to user

### Storage Issues
- Pre-flight storage checks
- Automatic pause when disk space low
- Option to change save location mid-recording

## Development Phases

### Phase 1: Core Recording
- Basic screen recording
- Area selection
- File saving

### Phase 2: Audio Integration
- Audio device selection
- Audio/video synchronization
- Mixing capabilities

### Phase 3: Input Tracking
- Mouse movement/click recording
- Keyboard stroke recording
- WebVTT output

### Phase 4: Polish
- Performance optimization
- UI refinements
- Advanced settings

## Testing Requirements

### Unit Tests
- Core recording engine
- File I/O operations
- Event processing

### Integration Tests
- Full recording workflow
- Multi-monitor scenarios
- Permission handling

### Performance Tests
- CPU/Memory usage monitoring
- Disk I/O benchmarks
- Frame drop detection

## Future Enhancements

1. **Cloud Integration**
   - Optional cloud backup
   - Sharing capabilities

2. **Advanced Editing**
   - Basic trim functionality
   - Annotation tools

3. **Streaming Support**
   - Live streaming capabilities
   - Network output options

4. **AI Features**
   - Automatic transcription
   - Smart compression

## Success Criteria

1. **Performance**: Maintains 60 FPS recording without frame drops
2. **Reliability**: Zero data loss, crash-resistant
3. **Usability**: Setup to recording in < 5 seconds
4. **Quality**: Pixel-perfect Retina recording
5. **Efficiency**: < 10% CPU usage during recording