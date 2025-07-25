//
//  PreferencesManager+Protocol.swift
//  DidYouGet
//
//  PreferencesManager protocol conformance
//
// this_file: DidYouGet/DidYouGet/Models/PreferencesManager+Protocol.swift

import Foundation
import SwiftUI

// MARK: - PreferencesProviding Protocol Conformance

extension PreferencesManager: PreferencesProviding {
    
    var defaultVideoQuality: VideoQuality {
        get { videoQuality }
        set { videoQuality = newValue }
    }
    
    var defaultFrameRate: Int {
        get { frameRate }
        set { frameRate = newValue }
    }
    
    var defaultSaveLocation: URL {
        get { 
            // Convert string path to URL
            URL(fileURLWithPath: saveLocation)
        }
        set { 
            // Convert URL to string path
            saveLocation = newValue.path
        }
    }
    
    var audioEnabled: Bool {
        get { recordAudio }
        set { recordAudio = newValue }
    }
    
    var showRecordingIndicator: Bool {
        // This property doesn't exist in current PreferencesManager
        // Return true as default for now
        true
    }
    
    func save() async {
        // PreferencesManager already saves automatically via UserDefaults
        // This method is here for protocol conformance
        UserDefaults.standard.synchronize()
    }
    
    func reset() async {
        // Reset all preferences to defaults
        videoQuality = .medium
        frameRate = 30
        saveLocation = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first ?? "~/Desktop"
        recordAudio = false
        mixAudioWithVideo = false
        recordMouseMovements = false
        recordKeystrokes = false
        
        // Force save
        UserDefaults.standard.synchronize()
    }
    
    func export(to url: URL) async throws {
        // Export preferences as JSON
        let preferences: [String: Any] = [
            "videoQuality": videoQuality.rawValue,
            "frameRate": frameRate,
            "saveLocation": saveLocation,
            "recordAudio": recordAudio,
            "mixAudioWithVideo": mixAudioWithVideo,
            "recordMouseMovements": recordMouseMovements,
            "recordKeystrokes": recordKeystrokes
        ]
        
        let data = try JSONSerialization.data(withJSONObject: preferences, options: .prettyPrinted)
        try data.write(to: url)
    }
    
    func load(from url: URL) async throws {
        // Load preferences from JSON
        let data = try Data(contentsOf: url)
        let preferences = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        
        if let quality = preferences["videoQuality"] as? String,
           let videoQualityEnum = VideoQuality(rawValue: quality) {
            videoQuality = videoQualityEnum
        }
        
        if let fps = preferences["frameRate"] as? Int {
            frameRate = fps
        }
        
        if let location = preferences["saveLocation"] as? String {
            saveLocation = location
        }
        
        if let audio = preferences["recordAudio"] as? Bool {
            recordAudio = audio
        }
        
        if let mix = preferences["mixAudioWithVideo"] as? Bool {
            mixAudioWithVideo = mix
        }
        
        if let mouse = preferences["recordMouseMovements"] as? Bool {
            recordMouseMovements = mouse
        }
        
        if let keyboard = preferences["recordKeystrokes"] as? Bool {
            recordKeystrokes = keyboard
        }
    }
}