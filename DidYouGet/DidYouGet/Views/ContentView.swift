import SwiftUI
import ScreenCaptureKit

@available(macOS 12.3, *)
struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    // Track whether view has appeared
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Recording status and main control
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    if recordingManager.isRecording {
                        Text(timeString(from: recordingManager.recordingDuration))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Text(recordingManager.isPaused ? "Recording paused" : "Recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready to record")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("⌘⇧R to start recording")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Primary control button - more compact and visually distinct
                if !recordingManager.isRecording {
                    Button(action: {
                        // Ensure preferences manager is set before starting recording
                        // This is a critical check as we've seen this issue multiple times
                        print("Record button clicked - first ensuring PreferencesManager is connected")
                        recordingManager.setPreferencesManager(preferencesManager)
                        
                        // Double-check after setting
                        if recordingManager.getPreferencesManager() == nil {
                            print("CRITICAL ERROR: PreferencesManager is still nil after explicit setting")
                            recordingManager.showAlert(title: "Recording Error", 
                                                     message: "Cannot start recording: preferences manager is not available. Please restart the application.")
                            return
                        }
                        
                        print("PreferencesManager confirmed connected, starting recording")
                        
                        // Use Task with user initiated priority for recording operation
                        Task(priority: .userInitiated) {
                            do {
                                // Start the actual recording process
                                // The RecordingManager will handle setting isRecording once setup is complete
                                try await recordingManager.startRecordingAsync()
                            } catch {
                                // Handle errors
                                print("Error starting recording: \(error.localizedDescription)")
                                await MainActor.run {
                                    recordingManager.showAlert(title: "Recording Error", message: error.localizedDescription)
                                }
                            }
                        }
                    }) {
                        Text("Record")
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .help("Start recording (⌘⇧R)")
                } else {
                    HStack(spacing: 8) {
                        // Stop button
                        Button(action: {
                            // Use a detached Task for better UI responsiveness
                            Task.detached(priority: .userInitiated) {
                                await recordingManager.stopRecording()
                            }
                        }) {
                            Image(systemName: "stop.fill")
                                .padding(6)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Stop recording")
                        
                        // Pause/Resume button
                        Button(action: {
                            if recordingManager.isPaused {
                                recordingManager.resumeRecording()
                            } else {
                                recordingManager.pauseRecording()
                            }
                        }) {
                            Image(systemName: recordingManager.isPaused ? "play.fill" : "pause.fill")
                                .padding(6)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                        .help(recordingManager.isPaused ? "Resume recording (⌘⇧P)" : "Pause recording (⌘⇧P)")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // Capture Source section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Capture Source")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Refresh button to update sources
                    Button(action: {
                        Task {
                            await recordingManager.loadAvailableContent()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh available sources")
                }
                
                // Simplified and unified segmented control
                Picker("", selection: $recordingManager.captureType) {
                    Label("Display", systemImage: "display").tag(RecordingManager.CaptureType.display)
                    Label("Window", systemImage: "macwindow").tag(RecordingManager.CaptureType.window)
                    Label("Area", systemImage: "rectangle.on.rectangle").tag(RecordingManager.CaptureType.area)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(1)
                
                // Source selection with improved display
                switch recordingManager.captureType {
                case .display:
                    if !recordingManager.availableDisplays.isEmpty {
                        Picker("", selection: $recordingManager.selectedScreen) {
                            ForEach(recordingManager.availableDisplays, id: \.displayID) { display in
                                Text("Display \(display.displayID) (\(Int(display.frame.width))×\(Int(display.frame.height)))")
                                    .tag(display as SCDisplay?)
                            }
                        }
                        .padding(.top, 4)
                    }
                case .window:
                    if !recordingManager.availableWindows.isEmpty {
                        Picker("", selection: $recordingManager.selectedWindow) {
                            ForEach(recordingManager.availableWindows, id: \.windowID) { window in
                                Text(window.title ?? "Window \(window.windowID)")
                                    .tag(window as SCWindow?)
                            }
                        }
                        .padding(.top, 4)
                    }
                case .area:
                    // Area capture info
                    if let area = recordingManager.recordingArea, 
                       let selectedScreen = recordingManager.selectedScreen {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Selected area: \(Int(area.width))×\(Int(area.height)) on Display \(selectedScreen.displayID)")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            if showAreaSelectedConfirmation {
                                Text(selectedAreaInfo)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(6)
                                    .padding(.top, 4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.top, 4)
                        .animation(.spring(), value: showAreaSelectedConfirmation)
                    } else {
                        Text("No area selected. Click 'Select Area...' below")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            // Quick settings with improved visuals - arranged vertically
            VStack(alignment: .leading, spacing: 12) {
                Text("Recording Options")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    // Audio recording toggle with improved visual
                    HStack {
                        Toggle(isOn: $preferencesManager.recordAudio) {
                            HStack(spacing: 8) {
                                Image(systemName: preferencesManager.recordAudio ? "mic.fill" : "mic.slash")
                                    .foregroundColor(preferencesManager.recordAudio ? .blue : .secondary)
                                    .font(.system(size: 14))
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Audio")
                                        .font(.subheadline)
                                        
                                    if preferencesManager.recordAudio {
                                        Text(preferencesManager.mixAudioWithVideo ? "Mixed with video" : "Separate file")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    
                    Divider()
                    
                    // Mouse recording toggle
                    HStack {
                        Toggle(isOn: $preferencesManager.recordMouseMovements) {
                            HStack(spacing: 8) {
                                Image(systemName: "cursorarrow.motionlines")
                                    .foregroundColor(preferencesManager.recordMouseMovements ? .green : .secondary)
                                    .font(.system(size: 14))
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mouse")
                                        .font(.subheadline)
                                        
                                    if preferencesManager.recordMouseMovements {
                                        Text("JSON format with click/hold detection")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                    
                    Divider()
                    
                    // Keyboard recording toggle
                    HStack {
                        Toggle(isOn: $preferencesManager.recordKeystrokes) {
                            HStack(spacing: 8) {
                                Image(systemName: "keyboard")
                                    .foregroundColor(preferencesManager.recordKeystrokes ? .purple : .secondary)
                                    .font(.system(size: 14))
                                    .frame(width: 16)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Keyboard")
                                        .font(.subheadline)
                                        
                                    if preferencesManager.recordKeystrokes {
                                        Text("JSON format with tap/hold detection")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            // Bottom buttons with improved styling
            HStack(spacing: 12) {
                if recordingManager.captureType == .area {
                    Button(action: {
                        // Will implement area selection later
                        selectArea()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "selection.pin.in.out")
                            Text("Select Area")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Select a specific area on the screen to record")
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                            Text("Preferences")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut(",", modifiers: .command)
                    .help("Open preferences (⌘,)")

                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                            Text("Quit")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .keyboardShortcut("q", modifiers: .command)
                    .help("Quit the application (⌘Q)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
        .padding(.vertical, 16)
        .background(Color(.windowBackgroundColor))
        .onAppear {
            // First, ensure that the PreferencesManager is set
            if !hasAppeared {
                print("ContentView appeared - ensuring PreferencesManager is connected")
                recordingManager.setPreferencesManager(preferencesManager)
                hasAppeared = true
            }
            
            // Reset recording state when view appears
            Task {
                print("Resetting recording state from ContentView onAppear")
                await recordingManager.resetRecordingState()
            }
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    // State to show selection confirmation
    @State private var showAreaSelectedConfirmation = false
    @State private var selectedAreaInfo = ""
    
    private func selectArea() {
        // Handle area selection - this will be implemented in a later task
        guard let selectedScreen = recordingManager.selectedScreen else { return }
        
        // Create a proper defined area that we can use for recording
        // For now, let's use a quarter of the screen in the center as a default
        let screenWidth = selectedScreen.frame.width
        let screenHeight = selectedScreen.frame.height
        
        // Make sure we use even dimensions for better encoding
        let areaWidth = screenWidth / 2
        let areaHeight = screenHeight / 2
        let areaX = (screenWidth - areaWidth) / 2
        let areaY = (screenHeight - areaHeight) / 2
        
        // Create the area rect - this MUST match what we're going to capture
        let selectedArea = CGRect(x: areaX, y: areaY, width: areaWidth, height: areaHeight)
        
        // Store the rect in our recordingManager
        recordingManager.recordingArea = selectedArea
        
        print("Area selection: \(Int(areaWidth))×\(Int(areaHeight)) at (\(Int(areaX)), \(Int(areaY)))")
        
        // Update UI with selected area info
        selectedAreaInfo = "Selected area: \(Int(areaWidth))×\(Int(areaHeight)) at (\(Int(areaX)), \(Int(areaY)))"
        
        // Update the UI to show confirmation
        showAreaSelectedConfirmation = true
        
        // Auto-hide the confirmation after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showAreaSelectedConfirmation = false
        }
    }
}