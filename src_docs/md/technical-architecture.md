# 5. Technical Architecture

## System Overview

### Architecture Principles

#### Protocol-Oriented Design
Did You Get It is built using Swift's protocol-oriented programming paradigm for maximum flexibility and testability:

```swift
// Core recording protocol defines the interface
protocol RecordingServiceProtocol {
    func startRecording(with configuration: RecordingConfiguration) async throws
    func stopRecording() async throws
    func pauseRecording() async throws
    func resumeRecording() async throws
    var isRecording: Bool { get }
    var currentConfiguration: RecordingConfiguration? { get }
}

// Concrete implementation with async/await
class RecordingManager: RecordingServiceProtocol {
    private let captureSession: CaptureSessionManager
    private let audioProcessor: AudioProcessor
    private let inputTracker: InputTracker
    
    // Implementation uses modern Swift concurrency
}
```

#### Async/Await Concurrency Model
All recording operations use Swift's modern concurrency features:

```swift
// Non-blocking recording operations
actor RecordingSession {
    private var isActive = false
    private var recordingTask: Task<Void, Error>?
    
    func start() async throws {
        guard !isActive else { return }
        
        recordingTask = Task {
            try await performRecording()
        }
        
        isActive = true
    }
    
    private func performRecording() async throws {
        // Concurrent processing of video, audio, and input streams
        async let videoStream = processVideoFrames()
        async let audioStream = processAudioSamples()
        async let inputEvents = processInputEvents()
        
        try await (videoStream, audioStream, inputEvents)
    }
}
```

#### Dependency Injection Architecture
Clean separation of concerns through dependency injection:

```swift
// Service container for dependency management
class ServiceContainer {
    static let shared = ServiceContainer()
    
    lazy var recordingManager: RecordingServiceProtocol = {
        RecordingManager(
            captureSession: captureSessionManager,
            audioProcessor: audioProcessor,
            inputTracker: inputTracker,
            fileManager: outputFileManager
        )
    }()
    
    lazy var captureSessionManager: CaptureSessionManager = {
        CaptureSessionManager(logger: logger)
    }()
}
```

## Core Components

### Recording Manager

#### Singleton Pattern with Protocol Interface
```swift
// Thread-safe singleton with protocol conformance
final class RecordingManager: ObservableObject, RecordingServiceProtocol {
    static let shared = RecordingManager()
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var currentStatus: RecordingStatus = .idle
    
    private let captureSession: CaptureSessionManager
    private let audioProcessor: AudioProcessorProtocol
    private let inputTracker: InputTrackerProtocol
    private let outputManager: OutputFileManagerProtocol
    
    private init() {
        // Initialize dependencies
        self.captureSession = CaptureSessionManager()
        self.audioProcessor = AudioProcessor()
        self.inputTracker = InputTracker()
        self.outputManager = OutputFileManager()
        
        setupRecordingPipeline()
    }
}
```

#### State Management
```swift
enum RecordingStatus {
    case idle
    case preparing
    case recording(startTime: Date)
    case paused(pauseTime: Date)
    case stopping
    case processing
    case error(RecordingError)
}

struct RecordingConfiguration {
    let videoSettings: VideoSettings
    let audioSettings: AudioSettings
    let inputTrackingSettings: InputTrackingSettings
    let outputSettings: OutputSettings
    let recordingArea: RecordingArea
}
```

### Capture Session Manager

#### ScreenCaptureKit Integration
```swift
import ScreenCaptureKit

class CaptureSessionManager: NSObject {
    private var stream: SCStream?
    private var streamOutput: SCStreamFrameOutput?
    private let logger: Logger
    
    func startCapture(configuration: RecordingConfiguration) async throws {
        // Get shareable content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Create content filter
        let filter = SCContentFilter(display: configuration.display, excludingWindows: [])
        
        // Configure stream
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = configuration.resolution.width
        streamConfig.height = configuration.resolution.height
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: Int32(configuration.frameRate))
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = configuration.showCursor
        
        // Create and start stream
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        try await stream?.startCapture(with: streamOutput)
    }
}
```

#### Frame Processing Pipeline
```swift
extension CaptureSessionManager: SCStreamDelegate, SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            Task { await processVideoFrame(sampleBuffer) }
        case .audio:
            Task { await processAudioSample(sampleBuffer) }
        @unknown default:
            logger.warning("Unknown stream output type: \(type)")
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Process frame with video processor
        await videoProcessor.processFrame(imageBuffer, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }
}
```

### Video Processing System

#### Video Processor Protocol
```swift
protocol VideoProcessorProtocol: Actor {
    func processFrame(_ imageBuffer: CVImageBuffer, timestamp: CMTime) async
    func configureEncoder(settings: VideoSettings) async throws
    func finishEncoding() async throws -> URL
}

actor VideoProcessor: VideoProcessorProtocol {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let processingQueue: DispatchQueue
    
    func processFrame(_ imageBuffer: CVImageBuffer, timestamp: CMTime) async {
        guard let videoInput = videoInput,
              let adaptor = adaptor,
              videoInput.isReadyForMoreMediaData else { return }
        
        // Append frame to video stream
        adaptor.append(imageBuffer, withPresentationTime: timestamp)
    }
}
```

#### Encoding Configuration
```swift
struct VideoSettings {
    let codec: AVVideoCodecType
    let width: Int
    let height: Int
    let frameRate: Int
    let bitRate: Int
    let keyFrameInterval: Int
    
    var compressionProperties: [String: Any] {
        return [
            AVVideoAverageBitRateKey: bitRate,
            AVVideoMaxKeyFrameIntervalKey: keyFrameInterval,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    }
}
```

### Audio Processing System

#### Multi-Source Audio Handling
```swift
protocol AudioProcessorProtocol: Actor {
    func startProcessing(configuration: AudioConfiguration) async throws
    func processSystemAudio(_ sampleBuffer: CMSampleBuffer) async
    func processMicrophoneAudio(_ sampleBuffer: CMSampleBuffer) async
    func finishProcessing() async throws -> [URL]
}

actor AudioProcessor: AudioProcessorProtocol {
    private var systemAudioWriter: AVAssetWriter?
    private var microphoneAudioWriter: AVAssetWriter?
    private var mixedAudioWriter: AVAssetWriter?
    
    func processSystemAudio(_ sampleBuffer: CMSampleBuffer) async {
        // Write to system audio track
        await writeAudioSample(sampleBuffer, to: systemAudioWriter)
        
        // Mix with microphone if enabled
        if configuration.shouldMixAudio {
            await mixAudioSample(sampleBuffer, source: .system)
        }
    }
}
```

#### Audio Format Management
```swift
struct AudioConfiguration {
    let systemAudioEnabled: Bool
    let microphoneEnabled: Bool
    let shouldMixAudio: Bool
    let sampleRate: Double
    let channelCount: Int
    let bitDepth: Int
    
    var formatDescription: AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(channelCount * MemoryLayout<Float32>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(channelCount * MemoryLayout<Float32>.size),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(bitDepth),
            mReserved: 0
        )
    }
}
```

### Input Tracking System

#### Event Monitoring Architecture
```swift
protocol InputTrackerProtocol {
    func startTracking(configuration: InputTrackingConfiguration) throws
    func stopTracking() throws
    var mouseEvents: AsyncStream<MouseEvent> { get }
    var keyboardEvents: AsyncStream<KeyboardEvent> { get }
}

class InputTracker: InputTrackerProtocol {
    private var mouseMonitor: Any?
    private var keyboardMonitor: Any?
    private let eventProcessor: InputEventProcessor
    
    func startTracking(configuration: InputTrackingConfiguration) throws {
        // Start mouse event monitoring
        mouseMonitor = NSEvent.addGlobalMonitorForEventsMatching([
            .mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .scrollWheel
        ]) { [weak self] event in
            Task { await self?.processMouseEvent(event) }
        }
        
        // Start keyboard event monitoring
        keyboardMonitor = NSEvent.addGlobalMonitorForEventsMatching([
            .keyDown, .keyUp, .flagsChanged
        ]) { [weak self] event in
            Task { await self?.processKeyboardEvent(event) }
        }
    }
}
```

#### Event Data Models
```swift
struct MouseEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let type: MouseEventType
    let location: CGPoint
    let buttonState: MouseButtonState?
    let scrollDelta: CGPoint?
    let clickCount: Int?
    
    enum MouseEventType: String, Codable {
        case move, click, scroll, drag
    }
    
    enum MouseButtonState: String, Codable {
        case down, up
    }
}

struct KeyboardEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: TimeInterval
    let type: KeyboardEventType
    let keyCode: UInt16
    let characters: String?
    let modifierFlags: NSEvent.ModifierFlags
    
    enum KeyboardEventType: String, Codable {
        case keyDown, keyUp, flagsChanged
    }
}
```

### File Management System

#### Output File Manager
```swift
protocol OutputFileManagerProtocol {
    func prepareOutputDirectory(for session: RecordingSession) async throws -> URL
    func saveVideoFile(_ data: Data, to directory: URL) async throws -> URL
    func saveAudioFiles(_ audioData: [AudioTrack], to directory: URL) async throws -> [URL]
    func saveInputData(_ events: InputEventCollection, to directory: URL) async throws -> URL
}

class OutputFileManager: OutputFileManagerProtocol {
    private let fileManager = FileManager.default
    private let sessionFormatter: SessionNameFormatter
    
    func prepareOutputDirectory(for session: RecordingSession) async throws -> URL {
        let baseURL = session.configuration.outputLocation
        let sessionName = sessionFormatter.formatName(for: session)
        let sessionURL = baseURL.appendingPathComponent(sessionName)
        
        try fileManager.createDirectory(at: sessionURL, withIntermediateDirectories: true)
        
        // Create subdirectories
        try fileManager.createDirectory(at: sessionURL.appendingPathComponent("audio"))
        try fileManager.createDirectory(at: sessionURL.appendingPathComponent("input_data"))
        try fileManager.createDirectory(at: sessionURL.appendingPathComponent("thumbnails"))
        
        return sessionURL
    }
}
```

## Performance Optimization

### Memory Management

#### Buffer Pool Implementation
```swift
actor FrameBufferPool {
    private var availableBuffers: [CVPixelBuffer] = []
    private let maxBufferCount: Int
    private let bufferAttributes: [String: Any]
    
    func acquireBuffer() -> CVPixelBuffer? {
        if let buffer = availableBuffers.popLast() {
            return buffer
        }
        
        // Create new buffer if pool not at capacity
        guard availableBuffers.count < maxBufferCount else { return nil }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            1920, 1080,
            kCVPixelFormatType_32BGRA,
            bufferAttributes as CFDictionary,
            &pixelBuffer
        )
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    func returnBuffer(_ buffer: CVPixelBuffer) {
        guard availableBuffers.count < maxBufferCount else { return }
        availableBuffers.append(buffer)
    }
}
```

#### Resource Monitoring
```swift
class PerformanceMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: UInt64 = 0
    @Published var diskUsage: UInt64 = 0
    @Published var frameDropCount: Int = 0
    
    private let updateTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    init() {
        updateTimer
            .sink { _ in
                Task { await self.updateMetrics() }
            }
            .store(in: &cancellables)
    }
    
    private func updateMetrics() async {
        // Monitor system resource usage
        cpuUsage = ProcessInfo.processInfo.systemUptime
        memoryUsage = getMemoryUsage()
        diskUsage = getDiskUsage()
    }
}
```

### Concurrent Processing

#### Task Coordination
```swift
actor RecordingCoordinator {
    private var videoTask: Task<Void, Error>?
    private var audioTask: Task<Void, Error>?
    private var inputTask: Task<Void, Error>?
    
    func startRecording() async throws {
        // Launch concurrent recording tasks
        videoTask = Task { try await processVideoStream() }
        audioTask = Task { try await processAudioStream() }
        inputTask = Task { try await processInputEvents() }
        
        // Monitor for completion or errors
        _ = try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.videoTask!.value }
            group.addTask { try await self.audioTask!.value }
            group.addTask { try await self.inputTask!.value }
            
            try await group.waitForAll()
        }
    }
}
```

## Error Handling and Logging

### Comprehensive Error System
```swift
enum RecordingError: LocalizedError, CustomStringConvertible {
    case permissionDenied(PermissionType)
    case insufficientDiskSpace(required: UInt64, available: UInt64)
    case audioDeviceUnavailable(deviceID: String)
    case encodingFailed(underlying: Error)
    case systemResourcesUnavailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission required for \(type.rawValue)"
        case .insufficientDiskSpace(let required, let available):
            return "Need \(required)MB, only \(available)MB available"
        // ... other cases
        }
    }
}
```

### Structured Logging
```swift
import OSLog

extension Logger {
    static let recording = Logger(subsystem: "it.didyouget.mac", category: "Recording")
    static let audio = Logger(subsystem: "it.didyouget.mac", category: "Audio")
    static let input = Logger(subsystem: "it.didyouget.mac", category: "Input")
    static let performance = Logger(subsystem: "it.didyouget.mac", category: "Performance")
}

// Usage throughout the application
Logger.recording.info("Recording session started with configuration: \(configuration)")
Logger.performance.warning("Frame drop detected: \(frameDropCount) frames")
```

Ready to learn about configuration options? Continue to [Configuration & Settings](configuration.md) for complete customization guidance.