# Did You Get It

A high-performance screen recording application for macOS with minimal UI overhead.

## Features

- **60 FPS Recording**: Capture screen content at up to 60 frames per second
- **Retina Support**: Full resolution recording on Retina displays
- **Audio Recording**: Optional audio capture from any input device
- **Input Tracking**: Record mouse movements, clicks, and keyboard strokes
- **Minimal UI**: Simple menu bar interface for quick access
- **Flexible Output**: Save recordings with configurable quality settings

## Requirements

- macOS 12.0 (Monterey) or later
- Screen recording permission
- Microphone permission (for audio recording)
- Accessibility permission (for input tracking)

## Installation

### Using Homebrew (coming soon)

```bash
brew install --cask didyouget
```

### Manual Installation

1. Download the latest DMG from the [releases page](https://github.com/twardoch/didyouget.it/releases)
2. Open the DMG and drag "Did You Get It" to your Applications folder
3. Launch the app from Applications or Spotlight

## Building from Source

### Requirements

- Xcode 15.0 or later
- Swift 6.0 or later
- macOS Monterey or later

### Build Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/twardoch/didyouget.it.git
   cd didyouget.it
   ```

2. Build using the Makefile:
   ```bash
   make build
   ```

3. Or using Swift Package Manager:
   ```bash
   swift build -c release
   ```

4. For a full release build with code signing:
   ```bash
   make release
   ```

## Usage

### Quick Start

1. Launch "Did You Get It" from your Applications folder
2. Click the menu bar icon to access recording controls
3. Click "Start Recording" or press ⌘⇧R
4. Select the screen area you want to record
5. Click "Stop" or press ⌘⇧R again to finish recording

### Keyboard Shortcuts

- **Start/Stop Recording**: ⌘⇧R
- **Pause/Resume**: ⌘⇧P

### Recording Options

- **Audio**: Toggle audio recording in the main menu
- **Mouse Tracking**: Enable to record mouse movements and clicks
- **Keyboard Tracking**: Enable to capture keystrokes with tap/hold-release detection
- **Quality**: Choose from Low, Medium, High, or Lossless in preferences

### Output Files

Recordings are saved to your Movies folder by default with the naming format:
```
DidYouGet_YYYY-MM-DD_HH-MM-SS.mp4
```

Additional files may be created:
- `.json` - Mouse movement, clicks, and drag data with event types
- `.json` - Keyboard input with tap/hold-release events

## Privacy & Security

"Did You Get It" requires several permissions to function:

1. **Screen Recording**: To capture screen content
2. **Microphone Access**: For audio recording (optional)
3. **Accessibility**: For mouse and keyboard tracking (optional)

All processing is done locally on your Mac. No data is sent to external servers.

## Configuration

Access preferences through the menu bar icon > Preferences or ⌘,

### Recording Settings
- Frame rate: 30 or 60 FPS
- Quality: Low, Medium, High, or Lossless
- Screen selection for multi-monitor setups

### Audio Settings
- Enable/disable audio recording
- Select input device
- Configure audio quality

### Input Tracking
- Toggle mouse movement recording
- Toggle keyboard input capture
- Privacy options for sensitive input

### Output Settings
- Change default save location
- Configure file naming
- Set up automatic organization

## Development

### Project Structure

```
DidYouGet/
├── DidYouGet/
│   ├── Models/         # Core data models and managers
│   ├── Views/          # SwiftUI views
│   ├── Controllers/    # App controllers
│   ├── Utilities/      # Helper functions and extensions
│   └── Resources/      # Assets and configuration files
├── Package.swift       # Swift Package Manager configuration
├── Makefile           # Build automation
└── README.md          # This file
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Troubleshooting

### Common Issues

**App doesn't start recording**
- Check that you've granted screen recording permission in System Settings > Privacy & Security
- Ensure no other screen recording apps are running

**No audio in recordings**
- Verify microphone permission is granted
- Check that the correct audio device is selected in preferences

**Can't track mouse/keyboard**
- Grant accessibility permission in System Settings
- Restart the app after granting permission

### Getting Help

- Check the [FAQ](https://didyouget.it/faq)
- Report issues on [GitHub](https://github.com/twardoch/didyouget.it/issues)
- Contact support at support@didyouget.it

## License

"Did You Get It" is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with Swift and SwiftUI
- Uses Apple's ScreenCaptureKit for efficient screen recording
- Inspired by the need for a simple, fast screen recorder

---

Made with ❤️ for the macOS community