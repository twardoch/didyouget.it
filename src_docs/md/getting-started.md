# 2. Getting Started

## Installation

### Download Options

#### Official Release (Recommended)
1. Visit [https://didyouget.it](https://didyouget.it)
2. Download the latest `.dmg` file
3. Open the downloaded file and drag "Did You Get It" to Applications
4. Launch from Applications folder or Spotlight

#### Build from Source
```bash
# Clone the repository
git clone https://github.com/twardoch/didyougetit-mac.git
cd didyougetit-mac

# Build and run
make build
./run.sh
```

### First Launch Setup

#### Required Permissions
On first launch, macOS will request several permissions:

1. **Screen Recording Permission**
   - Essential for video capture functionality
   - Go to System Preferences → Security & Privacy → Privacy → Screen Recording
   - Check the box next to "Did You Get It"

2. **Microphone Permission** (if audio recording enabled)
   - Required for microphone input
   - Go to System Preferences → Security & Privacy → Privacy → Microphone
   - Check the box next to "Did You Get It"

3. **Accessibility Permission** (for input tracking)
   - Needed for mouse and keyboard tracking
   - Go to System Preferences → Security & Privacy → Privacy → Accessibility
   - Check the box next to "Did You Get It"

#### Initial Configuration
The app will open with default settings optimized for most users:
- **Recording area**: Full screen of primary display
- **Frame rate**: 60 FPS
- **Audio**: System audio enabled, microphone disabled
- **Input tracking**: Mouse and keyboard tracking enabled
- **Output location**: Desktop folder

## Quick Start Guide

### Your First Recording

1. **Launch the app**
   ```
   Open Did You Get It from Applications or press Cmd+Space and type "Did You Get It"
   ```

2. **Check recording area**
   - The app will highlight the recording area with a subtle overlay
   - Default is full screen of your primary display

3. **Start recording**
   - Press the **Record** button or use keyboard shortcut `Cmd+R`
   - The interface will minimize to avoid recording UI elements

4. **Perform your actions**
   - Do whatever you want to record
   - Mouse movements and keyboard input are being tracked automatically

5. **Stop recording**
   - Press `Cmd+R` again or click the stop button in the menu bar
   - Files will be saved automatically to your configured location

### Understanding Output Files

After recording, you'll find these files in your output directory:

```
recording_2024-01-15_14-30-45/
├── video.mov           # Main video recording
├── audio.wav           # Audio track (if recorded separately)
├── mouse_events.json   # Mouse movement and click data
├── keyboard_events.json # Keyboard input data
└── metadata.json       # Recording session information
```

### Basic Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+R` | Start/Stop recording |
| `Cmd+P` | Open Preferences |
| `Cmd+Q` | Quit application |
| `Cmd+,` | Open Settings |
| `Esc` | Cancel current recording |

## Essential Settings

### Recording Area Configuration

#### Full Screen Recording
- **Default setting**: Captures entire primary display
- **Best for**: General screen recording, tutorials
- **Performance**: Optimal for single-display setups

#### Custom Area Selection
1. Open Preferences (`Cmd+,`)
2. Select "Custom Area" from Recording Area dropdown
3. Click "Select Area" button
4. Drag to define the recording rectangle
5. Click "Confirm Selection"

#### Multi-Display Setup
- **Display selection**: Choose specific display from dropdown
- **Area per display**: Define custom areas on each display
- **Performance note**: Recording multiple displays increases resource usage

### Audio Configuration

#### System Audio Recording
```
Settings → Audio → System Audio: Enabled
```
- Captures all system sounds (music, notifications, app audio)
- Uses ScreenCaptureKit's audio capture for synchronization

#### Microphone Recording
```
Settings → Audio → Microphone: Choose device
```
- Select from available microphone devices
- Adjust input levels with built-in level meter
- Real-time audio monitoring available

#### Audio Mixing Options
- **Separate tracks**: Save system and mic audio as separate files
- **Mixed output**: Combine into single audio track
- **Audio-only mode**: Record audio without video

### Input Tracking Settings

#### Precision Levels
- **High precision**: Sub-pixel mouse movement tracking
- **Standard precision**: Pixel-level accuracy (recommended)
- **Low precision**: Reduced data volume for long recordings

#### Event Filtering
- **All events**: Capture every mouse movement and key press
- **Significant events only**: Filter minor movements and key repeats
- **Clicks and keys only**: Record only deliberate actions

## First Recording Walkthrough

Let's create your first recording with optimal settings:

### Step 1: Prepare Your Workspace
```bash
# Create a dedicated folder for your recordings
mkdir ~/Desktop/DidYouGetIt-Recordings
```

### Step 2: Configure Settings
1. Open Did You Get It
2. Press `Cmd+,` to open preferences
3. Set output location to your recordings folder
4. Ensure these settings:
   - **Video**: 60 FPS, Full Quality
   - **Audio**: System Audio enabled
   - **Input Tracking**: Mouse and Keyboard enabled
   - **Recording Area**: Full Screen

### Step 3: Test Recording
1. Press `Cmd+R` to start recording
2. Open a few applications
3. Type some text
4. Move mouse around
5. Press `Cmd+R` to stop

### Step 4: Review Output
Navigate to your recordings folder and examine:
- **Video quality**: Smooth 60 FPS playback
- **Audio sync**: Perfect audio-video synchronization
- **Input data**: JSON files with precise timing data

## Performance Optimization

### For Best Results
- **Close unnecessary applications** before recording
- **Use SSD storage** for recording output
- **Monitor CPU and memory usage** in Activity Monitor
- **Record to local storage** rather than network drives

### Resource Management
```
Recommended settings for different scenarios:

Tutorials/Demos:
- 30 FPS video
- Standard input precision
- System audio enabled

Development/Debugging:
- 60 FPS video
- High input precision
- Separate audio tracks

Long-form Recording:
- 24 FPS video
- Low input precision
- Compressed output formats
```

## Troubleshooting First Launch

### Common Issues

#### "App cannot be opened" error
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /Applications/Did\ You\ Get\ It.app
```

#### Recording area not visible
1. Check Screen Recording permission in System Preferences
2. Restart the application after granting permission
3. Verify display settings aren't interfering

#### No audio in recordings
1. Verify microphone/system audio permissions
2. Check audio device selection in preferences
3. Test audio levels before recording

#### Performance issues
1. Close resource-intensive applications
2. Lower recording quality settings
3. Record to faster storage device

### Getting Help
- **Check logs**: `~/Library/Logs/DidYouGetIt/`
- **Reset preferences**: Delete `~/Library/Preferences/it.didyouget.mac.plist`
- **GitHub issues**: Report bugs and request features

Ready to explore advanced features? Continue to [Core Features](core-features.md) for detailed functionality coverage.