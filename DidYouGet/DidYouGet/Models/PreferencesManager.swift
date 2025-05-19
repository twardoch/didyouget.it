import Foundation
import SwiftUI

class PreferencesManager: ObservableObject {
    @AppStorage("frameRate") var frameRate: Int = 60
    @AppStorage("videoQuality") var videoQuality: VideoQuality = .high
    @AppStorage("recordAudio") var recordAudio: Bool = false
    @AppStorage("recordMouseMovements") var recordMouseMovements: Bool = false
    @AppStorage("recordKeystrokes") var recordKeystrokes: Bool = false
    @AppStorage("defaultSaveLocation") var defaultSaveLocation: String = ""
    @AppStorage("audioDeviceID") var selectedAudioDeviceID: String = ""
    
    init() {
        if defaultSaveLocation.isEmpty {
            defaultSaveLocation = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first?.path ?? ""
        }
    }
    
    enum VideoQuality: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case lossless = "Lossless"
        
        var compressionQuality: Float {
            switch self {
            case .low: return 0.3
            case .medium: return 0.5
            case .high: return 0.8
            case .lossless: return 1.0
            }
        }
    }
}