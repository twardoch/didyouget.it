# 4. User Interface

## Design Philosophy

### Minimal Interface Principles

#### Less is More
Did You Get It embodies extreme minimalism in its user interface design:

```swift
// Core UI principle: Essential controls only
struct ContentView: View {
    @StateObject private var recordingManager = RecordingManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            if recordingManager.isRecording {
                RecordingIndicator()
            } else {
                RecordingControls()
            }
        }
        .frame(width: 300, height: 200)
        .background(.ultraThinMaterial)
    }
}
```

**Key Design Decisions:**
- **Single-window interface**: No complex multi-panel layouts
- **Context-sensitive controls**: Show only relevant options
- **Immediate actions**: One-click recording start/stop
- **Visual feedback**: Clear status indication without clutter

#### Keyboard-First Workflow
The interface is designed to minimize mouse interaction:

```swift
// Keyboard shortcuts are primary interaction method
.keyboardShortcut("r", modifiers: .command) // Start/Stop recording
.keyboardShortcut(",", modifiers: .command) // Preferences
.keyboardShortcut("q", modifiers: .command) // Quit
```

### Main Interface Components

#### Recording Control Panel

**Primary Controls**
```swift
struct RecordingControls: View {
    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Large, prominent record button
            RecordButton()
                .frame(width: 80, height: 80)
            
            // Essential status information
            StatusDisplay()
            
            // Quick access settings
            QuickSettings()
        }
    }
}
```

**Record Button States**
- **Ready**: Large red circle, pulsing subtly
- **Recording**: Red square with stop icon, solid color
- **Processing**: Spinner with progress indication
- **Error**: Orange triangle with alert icon

#### Status Display Area

**Real-Time Information**
```swift
struct StatusDisplay: View {
    @ObservedObject var recorder: RecordingManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Recording duration
            Text(recorder.formattedDuration)
                .font(.system(.title2, design: .monospaced))
            
            // Performance indicators
            PerformanceIndicators()
            
            // Storage space warning
            if recorder.lowDiskSpace {
                DiskSpaceWarning()
            }
        }
    }
}
```

**Status Elements:**
- **Recording timer**: MM:SS format, updates every second
- **Frame rate indicator**: Current FPS with target comparison
- **Audio levels**: System and microphone input meters
- **Storage space**: Available disk space warning
- **Performance warning**: CPU/memory usage alerts

#### Quick Settings Panel

**Immediate Access Controls**
```swift
struct QuickSettings: View {
    var body: some View {
        HStack(spacing: 12) {
            // Recording area selector
            AreaSelector()
            
            // Audio source toggles
            AudioToggle(source: .system)
            AudioToggle(source: .microphone)
            
            // Input tracking toggle
            InputTrackingToggle()
        }
        .buttonStyle(.borderless)
    }
}
```

### Recording Area Visualization

#### Area Selection Overlay

**Visual Feedback System**
```swift
class AreaSelectionOverlay: NSView {
    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent overlay with recording area highlight
        NSColor.black.withAlphaComponent(0.3).setFill()
        bounds.fill()
        
        // Clear recording area
        NSColor.clear.setFill()
        recordingRect.fill(using: .clear)
        
        // Animated border around recording area
        drawAnimatedBorder()
    }
}
```

**Interactive Elements:**
- **Selection handles**: Drag to resize recording area
- **Dimension display**: Real-time width/height values
- **Grid alignment**: Snap to pixel boundaries
- **Window detection**: Highlight application windows

#### Multi-Display Handling

**Display Selection Interface**
```swift
struct DisplaySelector: View {
    @State private var selectedDisplay: DisplayInfo?
    
    var body: some View {
        VStack {
            ForEach(DisplayManager.shared.availableDisplays) { display in
                DisplayPreview(display: display)
                    .overlay(
                        display.isSelected ? SelectionIndicator() : nil
                    )
                    .onTapGesture {
                        selectedDisplay = display
                    }
            }
        }
    }
}
```

### Preferences Interface

#### Settings Organization

**Tabbed Settings Panel**
```swift
struct PreferencesView: View {
    var body: some View {
        TabView {
            RecordingSettings()
                .tabItem { Label("Recording", systemImage: "record.circle") }
            
            AudioSettings()
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
            
            InputSettings()
                .tabItem { Label("Input", systemImage: "keyboard") }
            
            OutputSettings()
                .tabItem { Label("Output", systemImage: "folder") }
            
            AdvancedSettings()
                .tabItem { Label("Advanced", systemImage: "gearshape") }
        }
        .frame(width: 600, height: 400)
    }
}
```

#### Recording Settings Tab

**Video Configuration**
```swift
struct RecordingSettings: View {
    @AppStorage("frameRate") private var frameRate: Int = 60
    @AppStorage("resolution") private var resolution: String = "native"
    
    var body: some View {
        Form {
            Section("Video Quality") {
                Picker("Frame Rate", selection: $frameRate) {
                    Text("24 FPS").tag(24)
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                }
                
                Picker("Resolution", selection: $resolution) {
                    Text("Native Retina").tag("native")
                    Text("Scaled Retina").tag("scaled")
                    Text("1080p HD").tag("1080p")
                    Text("Custom").tag("custom")
                }
            }
            
            Section("Recording Area") {
                RecordingAreaControls()
            }
        }
    }
}
```

#### Audio Settings Tab

**Audio Source Configuration**
```swift
struct AudioSettings: View {
    @AppStorage("systemAudioEnabled") private var systemAudio = true
    @AppStorage("microphoneEnabled") private var microphone = false
    
    var body: some View {
        Form {
            Section("Audio Sources") {
                Toggle("System Audio", isOn: $systemAudio)
                Toggle("Microphone", isOn: $microphone)
                
                if microphone {
                    MicrophoneSelector()
                    InputLevelMeter()
                }
            }
            
            Section("Audio Quality") {
                AudioQualitySettings()
            }
            
            Section("Audio Processing") {
                Toggle("Noise Reduction", isOn: $noiseReduction)
                Toggle("Auto Gain Control", isOn: $autoGain)
            }
        }
    }
}
```

### Menu Bar Integration

#### Menu Bar Icon States

**Status Indication**
```swift
class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    func updateIcon(for state: RecordingState) {
        switch state {
        case .idle:
            statusItem.button?.image = NSImage(systemSymbolName: "record.circle")
        case .recording:
            statusItem.button?.image = NSImage(systemSymbolName: "stop.circle.fill")
            statusItem.button?.image?.isTemplate = false
        case .processing:
            statusItem.button?.image = NSImage(systemSymbolName: "gear")
        }
    }
}
```

**Menu Bar Menu**
```swift
struct MenuBarMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Quick actions
            Button("Start Recording") { startRecording() }
                .keyboardShortcut("r", modifiers: .command)
            
            Button("Open Preferences") { openPreferences() }
                .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            // Recent recordings
            Menu("Recent Recordings") {
                ForEach(recentRecordings) { recording in
                    Button(recording.name) {
                        NSWorkspace.shared.open(recording.url)
                    }
                }
            }
            
            Divider()
            
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
```

### Recording Session UI

#### Recording Indicator

**Minimal Recording Feedback**
```swift
struct RecordingIndicator: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(), value: pulseAnimation)
            
            // Recording duration
            Text(recordingDuration)
                .font(.system(.title2, design: .monospaced))
                .foregroundColor(.primary)
        }
        .onAppear { pulseAnimation = true }
    }
}
```

#### Performance Overlay (Optional)

**Developer Mode Display**
```swift
struct PerformanceOverlay: View {
    @ObservedObject var metrics: RecordingMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FPS: \(metrics.currentFPS, specifier: "%.1f")")
            Text("Memory: \(metrics.memoryUsage)MB")
            Text("CPU: \(metrics.cpuUsage, specifier: "%.1f")%")
        }
        .font(.system(.caption, design: .monospaced))
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}
```

### Accessibility Features

#### VoiceOver Support

**Screen Reader Integration**
```swift
// Proper accessibility labels and hints
Button("Start Recording") { }
    .accessibilityLabel("Start screen recording")
    .accessibilityHint("Begins capturing screen content and input events")

Toggle("System Audio", isOn: $systemAudio)
    .accessibilityLabel("Record system audio")
    .accessibilityValue(systemAudio ? "Enabled" : "Disabled")
```

#### Keyboard Navigation

**Full Keyboard Control**
```swift
// Tab navigation through all controls
.focusable()
.onKeyPress(.tab) { _ in
    focusNextControl()
    return .handled
}

// Escape key cancellation
.onKeyPress(.escape) { _ in
    cancelCurrentOperation()
    return .handled
}
```

### Error and Status Communication

#### User-Friendly Error Messages

**Error Display System**
```swift
struct ErrorAlert: View {
    let error: RecordingError
    
    var body: some View {
        Alert(
            "Recording Error",
            message: Text(error.userFriendlyDescription),
            primaryButton: .default(Text("Retry")) {
                retryRecording()
            },
            secondaryButton: .cancel()
        )
    }
}
```

**Error Categories:**
- **Permission errors**: Clear guidance to system settings
- **Performance warnings**: Suggestions for quality adjustments
- **Storage issues**: Disk space and location problems
- **Hardware errors**: Audio/video device unavailability

#### Status Notifications

**Non-Intrusive Feedback**
```swift
// Subtle notifications for state changes
Text("Recording saved successfully")
    .foregroundColor(.secondary)
    .transition(.opacity.combined(with: .slide))
    .animation(.easeInOut(duration: 0.3), value: showNotification)
```

### Customization Options

#### Interface Themes

**Theme Selection**
```swift
enum InterfaceTheme: CaseIterable {
    case system, light, dark, minimal
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .minimal: return .dark
        }
    }
}
```

#### Layout Preferences

**Interface Density Options**
- **Compact**: Minimal spacing, small controls
- **Standard**: Default comfortable layout
- **Spacious**: Larger targets, more spacing

Ready to dive into the technical implementation? Continue to [Technical Architecture](technical-architecture.md) for detailed system design information.