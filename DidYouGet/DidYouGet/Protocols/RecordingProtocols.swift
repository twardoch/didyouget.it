//
//  RecordingProtocols.swift
//  DidYouGet
//
//  Protocol definitions for recording services
//
// this_file: DidYouGet/DidYouGet/Protocols/RecordingProtocols.swift

import Foundation
import AVFoundation
import ScreenCaptureKit

// MARK: - Core Recording Protocol

@MainActor
protocol RecordingService: AnyObject {
    var state: RecordingState { get }
    var recordingDuration: TimeInterval { get }
    var activeRecording: RecordingSession? { get }
    
    func startRecording(configuration: RecordingConfiguration) async throws -> RecordingSession
    func stopRecording() async throws -> URL
    func pauseRecording() async
    func resumeRecording() async
}

// MARK: - Video Processing Protocol

protocol VideoProcessing: AnyObject {
    var isConfigured: Bool { get }
    var encodedFrameCount: Int { get }
    
    func configure(settings: VideoSettings, outputURL: URL) throws
    func process(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws
    func finalize() async throws
}

// MARK: - Audio Processing Protocol

protocol AudioProcessing: AnyObject {
    var isConfigured: Bool { get }
    var isProcessing: Bool { get }
    
    func configureAudio(device: AVCaptureDevice?, settings: AudioSettings) throws
    func startProcessing() async throws
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) async throws
    func stopProcessing() async throws
    func finalize() async throws
}

// MARK: - Capture Session Protocol

protocol CaptureSessionProtocol: AnyObject {
    var isCapturing: Bool { get }
    var delegate: CaptureSessionDelegate? { get set }
    
    func availableContent() async throws -> SCShareableContent
    func startCapture(display: SCDisplay, captureArea: CGRect?, configuration: CaptureConfiguration) async throws
    func stopCapture() async throws
}

// MARK: - Capture Session Delegate

protocol CaptureSessionDelegate: AnyObject {
    func captureSession(_ session: CaptureSessionProtocol, didCapture sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType)
    func captureSession(_ session: CaptureSessionProtocol, didFailWithError error: Error)
}

// MARK: - Output File Management Protocol

protocol OutputFileManaging {
    var defaultLocation: URL { get set }
    var namingStrategy: FileNamingStrategy { get set }
    
    func prepareOutputURL(prefix: String?, metadata: RecordingMetadata?) throws -> URL
    func organizeRecording(from tempURL: URL, metadata: RecordingMetadata) async throws -> URL
    func cleanupOldRecordings(olderThan days: Int, keepMinimum: Int) async throws -> CleanupResult
}

// MARK: - Preferences Protocol

@MainActor
protocol PreferencesProviding: ObservableObject {
    var defaultVideoQuality: VideoQuality { get set }
    var defaultFrameRate: Int { get set }
    var defaultSaveLocation: URL { get set }
    var audioEnabled: Bool { get set }
    var showRecordingIndicator: Bool { get set }
    
    func save() async
    func reset() async
    func export(to url: URL) async throws
    func load(from url: URL) async throws
}

// MARK: - Permission Management Protocol

protocol PermissionManaging {
    func checkScreenRecordingPermission() async -> Bool
    func checkMicrophonePermission() async -> Bool
    func checkAccessibilityPermission() async -> Bool
    func requestScreenRecordingPermission() async -> Bool
    func requestMicrophonePermission() async -> Bool
    func requestAccessibilityPermission() async -> Bool
}

// MARK: - Version Management Protocol

protocol VersionProviding {
    var appVersion: String { get }
    var buildNumber: String { get }
    var bundleIdentifier: String { get }
    var isDebugBuild: Bool { get }
    func checkForUpdates() async throws -> UpdateInfo?
}

// MARK: - Supporting Types

enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopping
    case error(RecordingError)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.preparing, .preparing),
             (.recording, .recording),
             (.paused, .paused),
             (.stopping, .stopping):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

struct CaptureConfiguration {
    let frameRate: Int
    let resolution: CGSize?
    let colorSpace: CGColorSpace
    let pixelFormat: OSType
    let showsCursor: Bool
    let capturesAudio: Bool
    
    static var `default`: CaptureConfiguration {
        CaptureConfiguration(
            frameRate: 60,
            resolution: nil,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            pixelFormat: kCVPixelFormatType_32BGRA,
            showsCursor: true,
            capturesAudio: false
        )
    }
}

enum FileNamingStrategy {
    case timestamp
    case incremental
    case custom((RecordingMetadata?) -> String)
}

struct CleanupResult {
    let filesDeleted: Int
    let spaceRecovered: Int64
    let errors: [Error]
}

struct UpdateInfo {
    let version: String
    let releaseNotes: String
    let downloadURL: URL
    let isCritical: Bool
}

// MARK: - Error Types

enum RecordingError: LocalizedError {
    case permissionDenied(PermissionType)
    case alreadyRecording
    case notRecording
    case invalidConfiguration(String)
    case deviceNotFound(String)
    case encodingFailed(Error)
    case saveFailed(Error)
    case storageFull
    case captureFailure(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission denied for \(type.rawValue)"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No active recording"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .deviceNotFound(let device):
            return "Device not found: \(device)"
        case .encodingFailed(let error):
            return "Encoding failed: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Save failed: \(error.localizedDescription)"
        case .storageFull:
            return "Storage is full"
        case .captureFailure(let error):
            return "Capture failed: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied(let type):
            return "Grant \(type.rawValue) permission in System Settings"
        case .alreadyRecording:
            return "Stop the current recording before starting a new one"
        case .notRecording:
            return "Start a recording first"
        case .invalidConfiguration:
            return "Check your recording settings"
        case .deviceNotFound:
            return "Ensure the device is connected and available"
        case .encodingFailed:
            return "Try using different encoding settings"
        case .saveFailed:
            return "Check file permissions and available space"
        case .storageFull:
            return "Free up disk space and try again"
        case .captureFailure:
            return "Check screen recording permissions and try again"
        }
    }
}

enum PermissionType: String {
    case screenRecording = "Screen Recording"
    case microphone = "Microphone"
    case accessibility = "Accessibility"
}