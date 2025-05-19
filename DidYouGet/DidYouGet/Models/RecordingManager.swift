import Foundation
import AVFoundation
@preconcurrency import ScreenCaptureKit

@available(macOS 12.3, *)
@MainActor
class RecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var selectedScreen: SCDisplay?
    @Published var recordingArea: CGRect?
    
    private var captureSession: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var startTime: Date?
    private var timer: Timer?
    private var outputURL: URL?
    
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableWindows: [SCWindow] = []
    @Published var captureType: CaptureType = .display
    @Published var selectedWindow: SCWindow?
    
    enum CaptureType {
        case display
        case window
        case area
    }
    
    enum SCStreamType {
        case screen
        case audio
    }
    
    class SCStreamFrameOutput: NSObject, SCStreamOutput {
        private let handler: (CMSampleBuffer, SCStreamType) -> Void
        
        init(handler: @escaping (CMSampleBuffer, SCStreamType) -> Void) {
            self.handler = handler
            super.init()
        }
        
        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            switch type {
            case .screen:
                handler(sampleBuffer, .screen)
            case .audio:
                handler(sampleBuffer, .audio)
            case .microphone:
                // Handle microphone if needed
                break
            @unknown default:
                break
            }
        }
    }
    
    init() {
        checkPermissions()
        Task {
            await loadAvailableContent()
        }
    }
    
    func checkPermissions() {
        Task {
            let hasScreenRecordingPermission = await checkScreenRecordingPermission()
            if !hasScreenRecordingPermission {
                await requestScreenRecordingPermission()
            }
        }
    }
    
    private func checkScreenRecordingPermission() async -> Bool {
        // macOS 14+ offers better API, but for now we'll just return true
        return true
    }
    
    private func requestScreenRecordingPermission() async {
        // Permissions are requested automatically when capturing starts
        // We'll handle any errors when we start the capture
    }
    
    @MainActor
    func startRecording() async {
        guard !isRecording else { return }
        
        isRecording = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(self.startTime ?? Date())
            }
        }
        
        await setupCaptureSession()
    }
    
    @MainActor
    func stopRecording() async {
        guard isRecording else { return }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
        
        await teardownCaptureSession()
    }
    
    @MainActor
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        isPaused = true
        timer?.invalidate()
    }
    
    @MainActor
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        isPaused = false
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration = Date().timeIntervalSince(self.startTime ?? Date())
            }
        }
    }
    
    func loadAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.availableDisplays = content.displays
            self.availableWindows = content.windows.filter { window in
                // Filter out windows that are too small or from our own app
                window.frame.width > 50 && window.frame.height > 50 && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            
            // Set default display if none selected
            if selectedScreen == nil && !availableDisplays.isEmpty {
                selectedScreen = availableDisplays.first
            }
        } catch {
            print("Failed to load available content: \(error)")
        }
    }
    
    private func createOutputURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = "DidYouGetIt_\(timestamp).mov"
        
        let documentsPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func setupCaptureSession() async {
        do {
            outputURL = createOutputURL()
            
            // Get the content to capture
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Create stream configuration
            let streamConfig = SCStreamConfiguration()
            streamConfig.queueDepth = 5
            streamConfig.width = 1920
            streamConfig.height = 1080
            streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
            streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
            streamConfig.scalesToFit = true
            if #available(macOS 14.0, *) {
                streamConfig.preservesAspectRatio = true
            }
            
            // Get the display or window to capture
            let contentFilter: SCContentFilter
            switch captureType {
            case .display:
                guard let display = selectedScreen else { return }
                // Update configuration for display resolution
                streamConfig.width = Int(display.frame.width) * 2 // Retina
                streamConfig.height = Int(display.frame.height) * 2 // Retina
                contentFilter = SCContentFilter(display: display, excludingWindows: [])
            case .window:
                guard let window = selectedWindow else { return }
                contentFilter = SCContentFilter(desktopIndependentWindow: window)
            case .area:
                guard let display = selectedScreen, let area = recordingArea else { return }
                contentFilter = SCContentFilter(display: display, excludingWindows: [])
                streamConfig.width = Int(area.width) * 2 // Retina
                streamConfig.height = Int(area.height) * 2 // Retina
            }
            
            // Create the stream
            captureSession = SCStream(filter: contentFilter, configuration: streamConfig, delegate: nil)
            
            // Set up asset writer
            assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mov)
            
            // Configure video input
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: streamConfig.width,
                AVVideoHeightKey: streamConfig.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoExpectedSourceFrameRateKey: 60,
                    AVVideoMaxKeyFrameIntervalKey: 60,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            if assetWriter!.canAdd(videoInput!) {
                assetWriter!.add(videoInput!)
            }
            
            // Start asset writer
            assetWriter!.startWriting()
            
            // Start capturing
            await startCapture()
            
        } catch {
            print("Failed to setup capture session: \(error)")
        }
    }
    
    private func startCapture() async {
        guard let stream = captureSession else { return }
        
        // Create a handler for the stream frames
        let handler: (CMSampleBuffer, SCStreamType) -> Void = { [weak self] sampleBuffer, type in
            guard let self = self else { return }
            
            switch type {
            case .screen:
                self.processSampleBuffer(sampleBuffer)
            case .audio:
                // Handle audio if needed
                break
            @unknown default:
                break
            }
        }
        
        // Create output with handler
        let output = SCStreamFrameOutput(handler: handler)
        
        try? stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue.global())
        try? await stream.startCapture()
        assetWriter?.startSession(atSourceTime: .zero)
    }
    
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }
        
        videoInput.append(sampleBuffer)
    }
    
    private func teardownCaptureSession() async {
        if let stream = captureSession {
            try? await stream.stopCapture()
        }
        
        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }
        
        if let writer = assetWriter {
            await writer.finishWriting()
        }
        
        captureSession = nil
        assetWriter = nil
        videoInput = nil
        outputURL = nil
    }
}