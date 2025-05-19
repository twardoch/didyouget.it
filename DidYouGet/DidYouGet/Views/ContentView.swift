import SwiftUI

struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Recording status
            HStack {
                Image(systemName: recordingManager.isRecording ? "record.circle.fill" : "record.circle")
                    .foregroundColor(recordingManager.isRecording ? .red : .primary)
                    .font(.title2)
                
                if recordingManager.isRecording {
                    Text(timeString(from: recordingManager.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("Ready to record")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Control buttons
            HStack(spacing: 15) {
                if !recordingManager.isRecording {
                    Button(action: {
                        Task {
                            await recordingManager.startRecording()
                        }
                    }) {
                        Label("Start Recording", systemImage: "play.fill")
                    }
                    .controlSize(.large)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                } else {
                    Button(action: {
                        Task {
                            await recordingManager.stopRecording()
                        }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .controlSize(.large)
                    
                    if recordingManager.isPaused {
                        Button(action: {
                            recordingManager.resumeRecording()
                        }) {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .controlSize(.large)
                    } else {
                        Button(action: {
                            recordingManager.pauseRecording()
                        }) {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .controlSize(.large)
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                    }
                }
            }
            
            Divider()
            
            // Quick settings
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Record Audio", isOn: $preferencesManager.recordAudio)
                Toggle("Record Mouse", isOn: $preferencesManager.recordMouseMovements)
                Toggle("Record Keyboard", isOn: $preferencesManager.recordKeystrokes)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Bottom buttons
            HStack {
                Button("Select Area...") {
                    // TODO: Implement area selection
                }
                
                Spacer()
                
                Button("Preferences...") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
            .padding(.horizontal)
        }
        .frame(width: 300)
        .padding()
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}