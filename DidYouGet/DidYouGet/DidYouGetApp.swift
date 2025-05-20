import SwiftUI

@main
@available(macOS 13.0, *)
struct DidYouGetApp: App {
    // Define state objects as plain properties first
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var preferencesManager = PreferencesManager()
    
    init() {
        // Debug output
        print("=== APPLICATION INITIALIZATION ===")
        print("Application starting up. macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        // Connect the managers (essential for recording)
        recordingManager.setPreferencesManager(preferencesManager)
        
        if let _ = recordingManager.preferencesManager {
            print("PreferencesManager successfully connected to RecordingManager during app init")
        } else {
            print("WARNING: PreferencesManager not connected to RecordingManager during app init")
        }
    }
    
    var body: some Scene {
        // Use MenuBarExtra with minimal configuration
        MenuBarExtra("Did You Get It", systemImage: "record.circle") {
            ContentView()
                .environmentObject(recordingManager)
                .environmentObject(preferencesManager)
        }
        .menuBarExtraStyle(.window)
        
        // Include settings window
        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
        }
    }
}