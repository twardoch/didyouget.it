//
//  RecordingServiceTests.swift
//  DidYouGetTests
//
//  Tests for RecordingService protocol implementations
//
// this_file: Tests/DidYouGetTests/RecordingServiceTests.swift

import XCTest
@testable import DidYouGet

@MainActor
final class RecordingServiceTests: XCTestCase {
    
    var mockRecordingService: MockRecordingService!
    var mockVideoProcessor: MockVideoProcessor!
    var mockAudioProcessor: MockAudioProcessor!
    var mockPreferences: MockPreferencesProvider!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRecordingService = MockRecordingService()
        mockVideoProcessor = MockVideoProcessor()
        mockAudioProcessor = MockAudioProcessor()
        mockPreferences = MockPreferencesProvider()
    }
    
    override func tearDown() async throws {
        mockRecordingService = nil
        mockVideoProcessor = nil
        mockAudioProcessor = nil
        mockPreferences = nil
        try await super.tearDown()
    }
    
    // MARK: - RecordingService Tests
    
    func testStartRecording() async throws {
        // Given
        let outputURL = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = RecordingConfiguration(
            displayID: CGMainDisplayID(),
            videoSettings: VideoSettings(quality: .high, frameRate: 60),
            outputURL: outputURL
        )
        
        // When
        let session = try await mockRecordingService.startRecording(configuration: config)
        
        // Then
        XCTAssertTrue(mockRecordingService.startRecordingCalled)
        XCTAssertEqual(mockRecordingService.state, .recording)
        XCTAssertNotNil(mockRecordingService.activeRecording)
        XCTAssertEqual(session.configuration, config)
    }
    
    func testStartRecordingFailure() async {
        // Given
        mockRecordingService.shouldFailStart = true
        mockRecordingService.startError = RecordingError.permissionDenied(.screenRecording)
        
        let config = RecordingConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4")
        )
        
        // When/Then
        await assertThrowsError {
            _ = try await mockRecordingService.startRecording(configuration: config)
        } errorHandler: { error in
            XCTAssertEqual(error as? RecordingError, RecordingError.permissionDenied(.screenRecording))
        }
    }
    
    func testStopRecording() async throws {
        // Given - Start recording first
        let config = RecordingConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4")
        )
        _ = try await mockRecordingService.startRecording(configuration: config)
        
        // When
        let url = try await mockRecordingService.stopRecording()
        
        // Then
        XCTAssertTrue(mockRecordingService.stopRecordingCalled)
        XCTAssertEqual(mockRecordingService.state, .idle)
        XCTAssertNil(mockRecordingService.activeRecording)
        XCTAssertEqual(url, mockRecordingService.mockOutputURL)
    }
    
    func testPauseResume() async {
        // Given
        let config = RecordingConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4")
        )
        _ = try? await mockRecordingService.startRecording(configuration: config)
        
        // When - Pause
        await mockRecordingService.pauseRecording()
        
        // Then
        XCTAssertTrue(mockRecordingService.pauseRecordingCalled)
        XCTAssertEqual(mockRecordingService.state, .paused)
        
        // When - Resume
        await mockRecordingService.resumeRecording()
        
        // Then
        XCTAssertTrue(mockRecordingService.resumeRecordingCalled)
        XCTAssertEqual(mockRecordingService.state, .recording)
    }
    
    // MARK: - VideoProcessor Tests
    
    func testVideoProcessorConfiguration() throws {
        // Given
        let settings = VideoSettings(
            codec: .h264,
            resolution: .fullHD,
            frameRate: 60,
            quality: .high
        )
        let outputURL = URL(fileURLWithPath: "/tmp/video.mp4")
        
        // When
        try mockVideoProcessor.configure(settings: settings, outputURL: outputURL)
        
        // Then
        XCTAssertTrue(mockVideoProcessor.configureCalled)
        XCTAssertTrue(mockVideoProcessor.isConfigured)
    }
    
    func testVideoProcessorFrameProcessing() async throws {
        // Given
        try mockVideoProcessor.configure(
            settings: .default,
            outputURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        
        // Create a test pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            1920, 1080,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        // When
        if let buffer = pixelBuffer {
            let timestamp = CMTime(value: 0, timescale: 60)
            try await mockVideoProcessor.process(pixelBuffer: buffer, timestamp: timestamp)
        }
        
        // Then
        XCTAssertTrue(mockVideoProcessor.processCalled)
        XCTAssertEqual(mockVideoProcessor.encodedFrameCount, 1)
        XCTAssertEqual(mockVideoProcessor.processedFrames.count, 1)
    }
    
    func testVideoProcessorFinalize() async throws {
        // Given
        try mockVideoProcessor.configure(
            settings: .default,
            outputURL: URL(fileURLWithPath: "/tmp/video.mp4")
        )
        
        // When
        try await mockVideoProcessor.finalize()
        
        // Then
        XCTAssertTrue(mockVideoProcessor.finalizeCalled)
        XCTAssertFalse(mockVideoProcessor.isConfigured)
    }
    
    // MARK: - AudioProcessor Tests
    
    func testAudioProcessorConfiguration() throws {
        // Given
        let settings = AudioSettings(
            sampleRate: 48000,
            bitrate: 192000,
            codec: .aac
        )
        
        // When
        try mockAudioProcessor.configureAudio(device: nil, settings: settings)
        
        // Then
        XCTAssertTrue(mockAudioProcessor.configureCalled)
        XCTAssertTrue(mockAudioProcessor.isConfigured)
    }
    
    func testAudioProcessorLifecycle() async throws {
        // Given
        try mockAudioProcessor.configureAudio(device: nil, settings: .default)
        
        // When - Start
        try await mockAudioProcessor.startProcessing()
        
        // Then
        XCTAssertTrue(mockAudioProcessor.startCalled)
        XCTAssertTrue(mockAudioProcessor.isProcessing)
        
        // When - Stop
        try await mockAudioProcessor.stopProcessing()
        
        // Then
        XCTAssertTrue(mockAudioProcessor.stopCalled)
        XCTAssertFalse(mockAudioProcessor.isProcessing)
    }
    
    // MARK: - PreferencesProvider Tests
    
    func testPreferencesSave() async {
        // When
        await mockPreferences.save()
        
        // Then
        XCTAssertTrue(mockPreferences.saveCalled)
    }
    
    func testPreferencesReset() async {
        // Given
        mockPreferences.defaultVideoQuality = .high
        mockPreferences.defaultFrameRate = 60
        mockPreferences.audioEnabled = true
        
        // When
        await mockPreferences.reset()
        
        // Then
        XCTAssertTrue(mockPreferences.resetCalled)
        XCTAssertEqual(mockPreferences.defaultVideoQuality, .medium)
        XCTAssertEqual(mockPreferences.defaultFrameRate, 30)
        XCTAssertFalse(mockPreferences.audioEnabled)
    }
    
    func testPreferencesExport() async throws {
        // Given
        let exportURL = URL(fileURLWithPath: "/tmp/prefs.json")
        
        // When
        try await mockPreferences.export(to: exportURL)
        
        // Then
        XCTAssertTrue(mockPreferences.exportCalled)
    }
    
    // MARK: - Integration Tests
    
    func testRecordingConfiguration() {
        // Test configuration creation
        let config = RecordingConfiguration(
            displayID: CGMainDisplayID(),
            captureArea: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            videoSettings: VideoSettings(
                codec: .h265,
                resolution: .fullHD,
                frameRate: 60,
                quality: .high
            ),
            audioSettings: AudioSettings(
                sampleRate: 48000,
                bitrate: 192000,
                codec: .aac
            ),
            outputURL: URL(fileURLWithPath: "/tmp/recording.mp4"),
            metadata: RecordingMetadata(
                title: "Test Recording",
                tags: ["test", "demo"]
            )
        )
        
        XCTAssertEqual(config.videoSettings.codec, .h265)
        XCTAssertEqual(config.videoSettings.frameRate, 60)
        XCTAssertEqual(config.audioSettings?.sampleRate, 48000)
        XCTAssertNotNil(config.metadata)
    }
    
    func testRecordingSession() {
        // Test session creation
        let config = RecordingConfiguration(
            outputURL: URL(fileURLWithPath: "/tmp/test.mp4")
        )
        let session = RecordingSession(
            id: UUID(),
            startTime: Date(),
            configuration: config
        )
        
        // Test duration calculation
        XCTAssertGreaterThanOrEqual(session.duration, 0)
        
        // Test file size estimation
        let estimatedSize = session.estimatedFileSize
        XCTAssertGreaterThan(estimatedSize, 0)
    }
}

// MARK: - Test Helpers

func assertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but none was thrown")
    } catch {
        errorHandler(error)
    }
}