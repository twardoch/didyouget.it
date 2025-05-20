import SwiftUI

@main
@available(macOS 13.0, *)
struct DidYouGetApp: App {
    // Define state objects as plain properties first
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var preferencesManager = PreferencesManager()
    
    init() {
        // Connect the managers
        recordingManager.setPreferencesManager(preferencesManager)
        
        // Debug output
        print("Application starting up. macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
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