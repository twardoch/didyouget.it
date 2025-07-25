//
//  RecordingManager+Protocol.swift
//  DidYouGet
//
//  RecordingManager protocol conformance
//
// this_file: DidYouGet/DidYouGet/Models/RecordingManager+Protocol.swift

import Foundation
import AVFoundation
import ScreenCaptureKit

// MARK: - RecordingService Protocol Conformance

@available(macOS 12.3, *)
extension RecordingManager: RecordingService {
    
    var state: RecordingState {
        if isStoppingProcessActive {
            return .stopping
        } else if isPaused {
            return .paused
        } else if isRecording {
            return .recording
        } else {
            return .idle
        }
    }
    
    var activeRecording: RecordingSession? {
        guard isRecording,
              let startTime = startTime,
              let videoURL = videoOutputURL else {
            return nil
        }
        
        let config = RecordingConfiguration(
            displayID: selectedScreen?.displayID ?? 0,
            captureArea: recordingArea,
            videoSettings: VideoSettings(
                codec: .h264,
                resolution: recordingArea != nil ? 
                    Resolution.custom(width: Int(recordingArea!.width), height: Int(recordingArea!.height)) :
                    Resolution.native,
                frameRate: preferencesManager?.frameRate ?? 30,
                quality: preferencesManager?.videoQuality ?? .medium
            ),
            audioSettings: preferencesManager?.recordAudio == true ? AudioSettings.default : nil,
            outputURL: videoURL
        )
        
        return RecordingSession(
            id: UUID(),
            startTime: startTime,
            configuration: config
        )
    }
    
    func startRecording(configuration: RecordingConfiguration) async throws -> RecordingSession {
        // Map configuration to internal properties
        if let display = availableDisplays.first(where: { $0.displayID == configuration.displayID }) {
            selectedScreen = display
        }
        
        if let area = configuration.captureArea {
            captureType = .area
            recordingArea = area
        } else {
            captureType = .display
        }
        
        // Update preferences from configuration
        if let preferences = preferencesManager {
            preferences.frameRate = configuration.videoSettings.frameRate
            preferences.videoQuality = configuration.videoSettings.quality
            preferences.recordAudio = configuration.audioSettings != nil
        }
        
        // Start recording using existing method
        try await startRecordingAsync()
        
        // Return recording session
        guard let session = activeRecording else {
            throw RecordingError.captureFailure(NSError(domain: "RecordingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create recording session"]))
        }
        
        return session
    }
    
    func stopRecording() async throws -> URL {
        // Call existing stop method
        await stopRecording()
        
        // Return the video URL
        guard let url = videoOutputURL else {
            throw RecordingError.saveFailed(NSError(domain: "RecordingManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video file was created"]))
        }
        
        return url
    }
    
    func pauseRecording() async {
        pauseRecording()
    }
    
    func resumeRecording() async {
        resumeRecording()
    }
}

// MARK: - RecordingSession Implementation

class RecordingSession {
    let id: UUID
    let startTime: Date
    let configuration: RecordingConfiguration
    
    init(id: UUID, startTime: Date, configuration: RecordingConfiguration) {
        self.id = id
        self.startTime = startTime
        self.configuration = configuration
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var estimatedFileSize: Int64 {
        // Rough estimation based on bitrate and duration
        let bitrate = configuration.videoSettings.bitrate ?? 5_000_000 // 5 Mbps default
        let audioBitrate = configuration.audioSettings?.bitrate ?? 0
        let totalBitrate = bitrate + audioBitrate
        let bytes = Int64(Double(totalBitrate) * duration / 8.0)
        return bytes
    }
    
    func addMarker(type: MarkerType = .generic, label: String? = nil) async {
        // TODO: Implement marker functionality
        print("Marker added: \(type) - \(label ?? "No label")")
    }
    
    func takeScreenshot() async throws -> URL {
        // TODO: Implement screenshot functionality
        throw RecordingError.notRecording
    }
}

// MARK: - Supporting Types

enum MarkerType {
    case generic
    case chapter
    case important
    case error
}

// MARK: - Configuration Types

struct RecordingConfiguration: Codable, Equatable {
    let displayID: CGDirectDisplayID
    let captureArea: CGRect?
    let videoSettings: VideoSettings
    let audioSettings: AudioSettings?
    let outputURL: URL
    let metadata: RecordingMetadata?
    
    init(displayID: CGDirectDisplayID = CGMainDisplayID(),
         captureArea: CGRect? = nil,
         videoSettings: VideoSettings = .default,
         audioSettings: AudioSettings? = nil,
         outputURL: URL,
         metadata: RecordingMetadata? = nil) {
        self.displayID = displayID
        self.captureArea = captureArea
        self.videoSettings = videoSettings
        self.audioSettings = audioSettings
        self.outputURL = outputURL
        self.metadata = metadata
    }
}

struct VideoSettings: Codable, Equatable {
    let codec: VideoCodec
    let resolution: Resolution
    let frameRate: Int
    let bitrate: Int?
    let quality: VideoQuality
    let keyFrameInterval: Int?
    
    init(codec: VideoCodec = .h264,
         resolution: Resolution = .native,
         frameRate: Int = 30,
         bitrate: Int? = nil,
         quality: VideoQuality = .medium,
         keyFrameInterval: Int? = nil) {
        self.codec = codec
        self.resolution = resolution
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.quality = quality
        self.keyFrameInterval = keyFrameInterval
    }
    
    static let `default` = VideoSettings()
    
    enum VideoCodec: String, Codable {
        case h264
        case h265
        case prores
    }
}

struct AudioSettings: Codable, Equatable {
    let device: AudioDevice?
    let sampleRate: Int
    let bitrate: Int
    let channels: Int
    let codec: AudioCodec
    
    init(device: AudioDevice? = nil,
         sampleRate: Int = 44100,
         bitrate: Int = 128000,
         channels: Int = 2,
         codec: AudioCodec = .aac) {
        self.device = device
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.channels = channels
        self.codec = codec
    }
    
    static let `default` = AudioSettings()
    
    enum AudioCodec: String, Codable {
        case aac
        case mp3
        case pcm
        case opus
    }
}

struct AudioDevice: Codable, Equatable {
    let id: String
    let name: String
    let type: DeviceType
    
    enum DeviceType: String, Codable {
        case microphone
        case systemAudio
        case aggregated
    }
}

enum Resolution: Codable, Equatable {
    case native
    case fullHD  // 1920x1080
    case hd      // 1280x720
    case custom(width: Int, height: Int)
}

struct RecordingMetadata: Codable, Equatable {
    let title: String?
    let description: String?
    let tags: [String]?
    let createdAt: Date
    
    init(title: String? = nil, description: String? = nil, tags: [String]? = nil, createdAt: Date = Date()) {
        self.title = title
        self.description = description
        self.tags = tags
        self.createdAt = createdAt
    }
}