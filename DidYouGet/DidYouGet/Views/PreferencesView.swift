import SwiftUI

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
            
            InputTrackingSettingsView()
                .tabItem {
                    Label("Input Tracking", systemImage: "keyboard")
                }
                .tag(2)
            
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
    
    var body: some View {
        Form {
            Section("Audio Recording") {
                Toggle("Enable Audio Recording", isOn: $preferencesManager.recordAudio)
                
                if preferencesManager.recordAudio {
                    // TODO: Add audio device picker
                    Text("Audio device selection coming soon...")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}

struct InputTrackingSettingsView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        Form {
            Section("Mouse Tracking") {
                Toggle("Record Mouse Movements", isOn: $preferencesManager.recordMouseMovements)
            }
            
            Section("Keyboard Tracking") {
                Toggle("Record Keystrokes", isOn: $preferencesManager.recordKeystrokes)
                
                if preferencesManager.recordKeystrokes {
                    Text("Keystrokes will be saved in WebVTT format")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

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