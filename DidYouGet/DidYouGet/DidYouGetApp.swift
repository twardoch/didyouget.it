import SwiftUI

@main
@available(macOS 13.0, *)
struct DidYouGetApp: App {
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var preferencesManager = PreferencesManager()
    
    init() {
        // Connect the managers
        recordingManager.setPreferencesManager(preferencesManager)
    }
    
    var body: some Scene {
        MenuBarExtra("Did You Get It", systemImage: "record.circle") {
            ContentView()
                .environmentObject(recordingManager)
                .environmentObject(preferencesManager)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
        }
    }
}