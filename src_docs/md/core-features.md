# 3. Core Features

## Screen Recording Engine

### High-Performance Video Capture

#### ScreenCaptureKit Integration
Did You Get It leverages Apple's latest ScreenCaptureKit framework for optimal performance:

```swift
// Core recording architecture
class CaptureSessionManager {
    private var stream: SCStream?
    private let videoProcessor: VideoProcessor
    private let audioProcessor: AudioProcessor
    
    func startCapture(configuration: CaptureConfiguration) async throws {
        // 60 FPS, full-resolution capture with minimal latency
        let streamConfig = SCStreamConfiguration()
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
    }
}
```

#### Frame Rate Options
- **60 FPS**: Ultra-smooth recording for detailed demonstrations
- **30 FPS**: Balanced performance for most use cases
- **24 FPS**: Cinematic feel with lower resource usage
- **Variable FPS**: Adaptive frame rate based on content changes

#### Resolution Settings
- **Native Retina**: Full display resolution (e.g., 3024×1964 on MacBook Pro)
- **Scaled Retina**: 2x scaling for smaller files with excellent quality
- **Standard HD**: 1920×1080 for universal compatibility
- **Custom resolution**: User-defined output dimensions

### Recording Area Management

#### Full Screen Capture
```
Default Mode: Complete display capture
- Captures entire selected display
- Optimal performance for single-display setups
- Automatic handling of display changes
- Menu bar and dock included by default
```

#### Custom Area Selection
Interactive area selection with precision controls:

1. **Visual Selection Tool**
   - Drag to define recording rectangle
   - Real-time dimension display
   - Snap-to-window functionality
   - Grid alignment assistance

2. **Coordinate-Based Definition**
   ```json
   {
     "recording_area": {
       "x": 100,
       "y": 100,
       "width": 1200,
       "height": 800,
       "display_id": 1
     }
   }
   ```

3. **Window-Based Capture**
   - Select specific application windows
   - Follow window movement automatically
   - Exclude or include window shadows
   - Handle window resizing gracefully

#### Multi-Display Support

**Display Detection and Selection**
```swift
// Automatic display enumeration
let displays = SCShareableContent.displays
for display in displays {
    print("Display: \(display.displayID), Size: \(display.frame.size)")
}
```

**Recording Strategies**
- **Single display**: Record one display with full resources
- **Multi-display span**: Record across multiple displays as single canvas
- **Independent recording**: Separate recording streams per display
- **Display switching**: Change target display during recording

## Audio Recording System

### Multi-Source Audio Capture

#### System Audio Recording
Captures all system-generated audio with perfect synchronization:

```swift
class AudioProcessor {
    func captureSystemAudio() async throws {
        // Capture system audio through ScreenCaptureKit
        let filter = SCContentFilter(excludingApplications: [], 
                                   exceptingWindows: [])
        // Audio automatically synced with video stream
    }
}
```

**Features:**
- **Application-specific filtering**: Include/exclude specific app audio
- **System sounds**: Notifications, alerts, and UI sounds
- **Media playback**: Music, videos, and streaming audio
- **Perfect synchronization**: Frame-accurate audio-video alignment

#### Microphone Recording
High-quality microphone input with real-time monitoring:

- **Device selection**: Choose from all available audio input devices
- **Input level monitoring**: Real-time audio level visualization
- **Noise reduction**: Built-in audio processing filters
- **Sample rate options**: 44.1kHz, 48kHz, or 96kHz recording

#### Audio Mixing and Processing

**Real-Time Mixing**
```swift
// Mix multiple audio sources in real-time
let mixer = AVAudioMixerNode()
mixer.addInputWithFormat(systemAudioFormat, for: systemAudioBus)
mixer.addInputWithFormat(microphoneFormat, for: microphoneBus)
```

**Output Formats**
- **Separate tracks**: Individual files for each audio source
- **Mixed stereo**: Combined audio in single stereo track  
- **Multi-channel**: Preserve individual channels for post-processing
- **Lossless options**: FLAC, ALAC for professional use

**Audio Quality Settings**
```json
{
  "audio_settings": {
    "system_audio": {
      "enabled": true,
      "sample_rate": 48000,
      "bit_depth": 24,
      "format": "AAC"
    },
    "microphone": {
      "enabled": true,
      "device_id": "default",
      "gain": 0.8,
      "noise_reduction": true
    }
  }
}
```

## Input Tracking Engine

### Mouse Movement Tracking

#### High-Precision Movement Capture
```swift
class MouseTracker {
    func trackMouseEvents() {
        // Sub-pixel precision mouse tracking
        NSEvent.addGlobalMonitorForEventsMatching([.mouseMoved, .leftMouseDown, .rightMouseDown]) { event in
            let location = NSEvent.mouseLocation
            let timestamp = event.timestamp
            
            let mouseEvent = MouseEvent(
                x: location.x,
                y: location.y,
                timestamp: timestamp,
                type: event.type,
                precision: .subPixel
            )
        }
    }
}
```

**Tracking Capabilities**
- **Movement precision**: Sub-pixel accuracy for smooth playback
- **Click detection**: Left, right, and middle button events
- **Drag operations**: Start, continue, and end drag events
- **Scroll tracking**: Wheel and trackpad scroll events
- **Gesture recognition**: Multi-touch trackpad gestures

**Output Format**
```json
{
  "mouse_events": [
    {
      "timestamp": 1642261845.123456,
      "type": "move",
      "x": 1024.5,
      "y": 768.25,
      "screen_id": 1
    },
    {
      "timestamp": 1642261845.567890,
      "type": "click",
      "button": "left",
      "state": "down",
      "x": 1024.5,
      "y": 768.25
    }
  ]
}
```

### Keyboard Input Tracking

#### Comprehensive Keystroke Capture
```swift
class KeyboardTracker {
    func trackKeyboardEvents() {
        NSEvent.addGlobalMonitorForEventsMatching([.keyDown, .keyUp, .flagsChanged]) { event in
            let keyEvent = KeyboardEvent(
                keyCode: event.keyCode,
                characters: event.characters,
                modifiers: event.modifierFlags,
                timestamp: event.timestamp,
                eventType: event.type
            )
        }
    }
}
```

**Captured Data**
- **Key codes**: Raw key codes for accurate replay
- **Character representation**: Actual characters typed
- **Modifier states**: Cmd, Opt, Ctrl, Shift combinations
- **Timing precision**: Millisecond-accurate timestamps
- **Hold duration**: Key press and release timing

**Privacy Considerations**
```json
{
  "privacy_settings": {
    "capture_mode": "keys_only",  // "keys_only", "characters", "both"
    "exclude_passwords": true,
    "exclude_secure_fields": true,
    "anonymize_text": false
  }
}
```

### Event Correlation and Analysis

#### Cross-Device Event Matching
- **Temporal synchronization**: Match events across input devices
- **Action grouping**: Identify related events (drag operations, text selection)
- **Gesture recognition**: Detect common UI interaction patterns
- **Performance metrics**: Calculate interaction timing and efficiency

#### Data Export Formats

**JSON Output Structure**
```json
{
  "session_metadata": {
    "start_time": "2024-01-15T14:30:45.123Z",
    "end_time": "2024-01-15T14:35:22.456Z",
    "recording_area": {...},
    "system_info": {...}
  },
  "mouse_events": [...],
  "keyboard_events": [...],
  "system_events": [...]
}
```

**CSV Export for Analysis**
```csv
timestamp,event_type,device,x,y,key_code,characters,modifiers
1642261845.123,mouse_move,mouse,1024.5,768.25,,,
1642261845.567,key_down,keyboard,,,65,a,0
1642261845.890,key_up,keyboard,,,65,a,0
```

## Recording Session Management

### Session Configuration

#### Pre-Recording Setup
```swift
struct RecordingConfiguration {
    let recordingArea: RecordingArea
    let videoSettings: VideoSettings
    let audioSettings: AudioSettings
    let inputTracking: InputTrackingSettings
    let outputSettings: OutputSettings
}
```

#### Dynamic Configuration Changes
- **Area adjustment**: Modify recording area during session
- **Quality settings**: Change frame rate and resolution on-the-fly
- **Audio routing**: Switch audio sources during recording
- **Input sensitivity**: Adjust tracking precision while recording

### File Management

#### Output Organization
```
Output Directory Structure:
session_2024-01-15_14-30-45/
├── metadata.json          # Session configuration and info
├── video.mov             # Primary video recording
├── audio/
│   ├── system.wav        # System audio track
│   ├── microphone.wav    # Microphone audio track
│   └── mixed.wav         # Combined audio (if enabled)
├── input_data/
│   ├── mouse_events.json # Mouse interaction data
│   ├── keyboard_events.json # Keyboard input data
│   └── combined_events.json # Merged event timeline
└── thumbnails/
    ├── preview.jpg       # Session preview image
    └── timeline/         # Timeline thumbnail images
        ├── 00001.jpg
        ├── 00002.jpg
        └── ...
```

#### Automatic File Naming
```json
{
  "naming_template": "session_{date}_{time}",
  "date_format": "YYYY-MM-DD",
  "time_format": "HH-mm-ss",
  "include_duration": true,
  "custom_prefix": "demo_"
}
```

### Performance Monitoring

#### Real-Time Metrics
- **Frame rate stability**: Monitor actual vs. target frame rate
- **Memory usage**: Track recording buffer and processing memory
- **Disk I/O**: Monitor write speeds and available storage
- **CPU utilization**: Balance quality with system performance

#### Quality Assurance
```swift
struct RecordingMetrics {
    let averageFrameRate: Double
    let droppedFrames: Int
    let audioBufferUnderruns: Int
    let memoryPeakUsage: UInt64
    let diskWriteSpeed: Double
}
```

Ready to learn about the user interface design? Continue to [User Interface](user-interface.md) for complete UI documentation.