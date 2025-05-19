import SwiftUI

@main
struct DidYouGetApp: App {
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var preferencesManager = PreferencesManager()
    
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