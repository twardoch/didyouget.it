//
//  MockRecordingService.swift
//  DidYouGetTests
//
//  Mock implementation of RecordingService for testing
//
// this_file: Tests/DidYouGetTests/Mocks/MockRecordingService.swift

import Foundation
@testable import DidYouGet

@MainActor
class MockRecordingService: RecordingService {
    
    // Mock state
    var mockState: RecordingState = .idle
    var mockDuration: TimeInterval = 0
    var mockActiveRecording: RecordingSession?
    
    // Tracking calls
    var startRecordingCalled = false
    var stopRecordingCalled = false
    var pauseRecordingCalled = false
    var resumeRecordingCalled = false
    
    // Mock responses
    var shouldFailStart = false
    var shouldFailStop = false
    var startError: Error?
    var stopError: Error?
    var mockOutputURL: URL = URL(fileURLWithPath: "/tmp/mock_recording.mp4")
    
    // Protocol implementation
    var state: RecordingState {
        mockState
    }
    
    var recordingDuration: TimeInterval {
        mockDuration
    }
    
    var activeRecording: RecordingSession? {
        mockActiveRecording
    }
    
    func startRecording(configuration: RecordingConfiguration) async throws -> RecordingSession {
        startRecordingCalled = true
        
        if shouldFailStart {
            throw startError ?? RecordingError.captureFailure(NSError(domain: "Mock", code: -1))
        }
        
        let session = RecordingSession(
            id: UUID(),
            startTime: Date(),
            configuration: configuration
        )
        
        mockActiveRecording = session
        mockState = .recording
        
        return session
    }
    
    func stopRecording() async throws -> URL {
        stopRecordingCalled = true
        
        if shouldFailStop {
            throw stopError ?? RecordingError.saveFailed(NSError(domain: "Mock", code: -1))
        }
        
        mockState = .idle
        mockActiveRecording = nil
        mockDuration = 0
        
        return mockOutputURL
    }
    
    func pauseRecording() async {
        pauseRecordingCalled = true
        mockState = .paused
    }
    
    func resumeRecording() async {
        resumeRecordingCalled = true
        mockState = .recording
    }
}

// MARK: - Mock Video Processor

class MockVideoProcessor: VideoProcessing {
    
    var mockIsConfigured = false
    var mockEncodedFrameCount = 0
    
    var configureCalled = false
    var processCalled = false
    var finalizeCalled = false
    
    var processedFrames: [CVPixelBuffer] = []
    var processedTimestamps: [CMTime] = []
    
    var isConfigured: Bool {
        mockIsConfigured
    }
    
    var encodedFrameCount: Int {
        mockEncodedFrameCount
    }
    
    func configure(settings: VideoSettings, outputURL: URL) throws {
        configureCalled = true
        mockIsConfigured = true
    }
    
    func process(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws {
        processCalled = true
        processedFrames.append(pixelBuffer)
        processedTimestamps.append(timestamp)
        mockEncodedFrameCount += 1
    }
    
    func finalize() async throws {
        finalizeCalled = true
        mockIsConfigured = false
    }
}

// MARK: - Mock Audio Processor

class MockAudioProcessor: AudioProcessing {
    
    var mockIsConfigured = false
    var mockIsProcessing = false
    
    var configureCalled = false
    var startCalled = false
    var processCalled = false
    var stopCalled = false
    var finalizeCalled = false
    
    var isConfigured: Bool {
        mockIsConfigured
    }
    
    var isProcessing: Bool {
        mockIsProcessing
    }
    
    func configureAudio(device: AVCaptureDevice?, settings: AudioSettings) throws {
        configureCalled = true
        mockIsConfigured = true
    }
    
    func startProcessing() async throws {
        startCalled = true
        mockIsProcessing = true
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) async throws {
        processCalled = true
    }
    
    func stopProcessing() async throws {
        stopCalled = true
        mockIsProcessing = false
    }
    
    func finalize() async throws {
        finalizeCalled = true
        mockIsConfigured = false
        mockIsProcessing = false
    }
}

// MARK: - Mock Preferences Provider

@MainActor
class MockPreferencesProvider: PreferencesProviding {
    @Published var defaultVideoQuality: VideoQuality = .medium
    @Published var defaultFrameRate: Int = 30
    @Published var defaultSaveLocation: URL = URL(fileURLWithPath: "/tmp")
    @Published var audioEnabled: Bool = false
    @Published var showRecordingIndicator: Bool = true
    
    var saveCalled = false
    var resetCalled = false
    var exportCalled = false
    var loadCalled = false
    
    func save() async {
        saveCalled = true
    }
    
    func reset() async {
        resetCalled = true
        defaultVideoQuality = .medium
        defaultFrameRate = 30
        audioEnabled = false
        showRecordingIndicator = true
    }
    
    func export(to url: URL) async throws {
        exportCalled = true
    }
    
    func load(from url: URL) async throws {
        loadCalled = true
    }
}