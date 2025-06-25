import SwiftUI
import AVFoundation

struct PreferencesView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingSettingsView()
                .tabItem {
                    Label("Recording", systemImage: "video")
                }
                .tag(0)
            
            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
                .tag(1)
            
            // InputTrackingSettingsView() // Removed for MVP
            //     .tabItem {
            //         Label("Input Tracking", systemImage: "keyboard")
            //     }
            //     .tag(2)
            
            OutputSettingsView()
                .tabItem {
                    Label("Output", systemImage: "folder")
                }
                .tag(3)
        }
        .frame(width: 500, height: 400)
    }
}

struct RecordingSettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        Form {
            Section("Video Settings") {
                Picker("Frame Rate", selection: $preferencesManager.frameRate) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                }
                
                Picker("Quality", selection: $preferencesManager.videoQuality) {
                    ForEach(PreferencesManager.VideoQuality.allCases, id: \.self) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
            }
        }
        .padding()
    }
}

struct AudioSettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @State private var audioDevices: [AudioManager.AudioDevice] = []
    @State private var selectedDevice: AudioManager.AudioDevice?
    
    var body: some View {
        Form {
            Section("Audio Recording") {
                Toggle("Enable Audio Recording", isOn: $preferencesManager.recordAudio)
                
                if preferencesManager.recordAudio {
                    Toggle("Mix Audio with Video", isOn: $preferencesManager.mixAudioWithVideo)
                        .help("When enabled, audio will be mixed with the video file. When disabled, audio will be saved as a separate file.")
                    
                    Picker("Input Device", selection: $selectedDevice) {
                        Text("None").tag(nil as AudioManager.AudioDevice?)
                        ForEach(audioDevices) { device in
                            Text(device.name).tag(device as AudioManager.AudioDevice?)
                        }
                    }
                    .disabled(audioDevices.isEmpty)
                    .onChange(of: selectedDevice) { newDevice in
                        if let device = newDevice {
                            preferencesManager.selectedAudioDeviceID = device.id
                        } else {
                            preferencesManager.selectedAudioDeviceID = ""
                        }
                    }
                    
                    if audioDevices.isEmpty {
                        Text("No audio input devices found")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadAudioDevices()
        }
    }
    
    private func loadAudioDevices() {
        audioDevices = AudioManager.shared.getAudioDevices()
        
        // Set default device if nothing is selected
        if preferencesManager.selectedAudioDeviceID.isEmpty && !audioDevices.isEmpty {
            if let defaultDevice = AudioManager.shared.getDefaultInputDevice() {
                selectedDevice = defaultDevice
                preferencesManager.selectedAudioDeviceID = defaultDevice.id
            } else {
                selectedDevice = audioDevices.first
                preferencesManager.selectedAudioDeviceID = audioDevices.first?.id ?? ""
            }
        } else {
            selectedDevice = audioDevices.first(where: { $0.id == preferencesManager.selectedAudioDeviceID })
        }
    }
}

// struct InputTrackingSettingsView: View { // Removed for MVP
//     @EnvironmentObject var preferencesManager: PreferencesManager
    
//     var body: some View {
//         Form {
//             Section("Mouse Tracking") {
//                 Toggle("Record Mouse Movements", isOn: $preferencesManager.recordMouseMovements)
                
//                 if preferencesManager.recordMouseMovements {
//                     Text("Mouse movements and clicks will be saved in JSON format with tap/hold-release detection (200ms threshold)")
//                         .foregroundColor(.secondary)
//                         .font(.caption)
//                         .fixedSize(horizontal: false, vertical: true)
//                 }
//             }
            
//             Section("Keyboard Tracking") {
//                 Toggle("Record Keystrokes", isOn: $preferencesManager.recordKeystrokes)
                
//                 if preferencesManager.recordKeystrokes {
//                     Text("Keystrokes will be saved in JSON format with tap/hold-release detection (200ms threshold)")
//                         .foregroundColor(.secondary)
//                         .font(.caption)
//                         .fixedSize(horizontal: false, vertical: true)
                    
//                     Text("Sensitive input (passwords) will be masked")
//                         .foregroundColor(.secondary)
//                         .font(.caption)
//                 }
//             }
            
//             // Permissions information
//             Section("Permissions Required") {
//                 Text("Input tracking requires Accessibility permissions")
//                     .foregroundColor(.secondary)
//                     .font(.caption)
                
//                 Button("Open System Settings") {
//                     NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
//                 }
//             }
//         }
//         .padding()
//     }
// }

struct OutputSettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @State private var selectedPath: String = ""
    
    var body: some View {
        Form {
            Section("Save Location") {
                HStack {
                    Text(preferencesManager.defaultSaveLocation.isEmpty ? "Choose location..." : preferencesManager.defaultSaveLocation)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Choose...") {
                        selectFolder()
                    }
                }
            }
            
            Section("File Naming") {
                Text("Files will be named: DidYouGet_YYYY-MM-DD_HH-MM-SS.mp4")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            selectedPath = preferencesManager.defaultSaveLocation
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            preferencesManager.defaultSaveLocation = url.path
            selectedPath = url.path
        }
    }
}