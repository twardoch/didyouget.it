import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import ObjectiveC
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class RecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var selectedScreen: SCDisplay?
    @Published var recordingArea: CGRect?
    
    private var captureSession: SCStream?
    private var videoAssetWriter: AVAssetWriter?
    private var audioAssetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var startTime: Date?
    private var timer: Timer?
    private var videoOutputURL: URL?
    private var audioOutputURL: URL?
    private var mouseTrackingURL: URL?
    private var keyboardTrackingURL: URL?
    
    // Input tracking
    private var mouseTracker = MouseTracker()
    private var keyboardTracker = KeyboardTracker()
    
    // Statistics for diagnostics
    private var videoFramesProcessed: Int = 0
    private var audioSamplesProcessed: Int = 0
    
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
        
        do {
            // Check if we have all the required parameters before starting
            switch captureType {
            case .display:
                guard selectedScreen != nil else {
                    showAlert(title: "Recording Error", message: "No display selected. Please select a display to record.")
                    return
                }
            case .window:
                guard selectedWindow != nil else {
                    showAlert(title: "Recording Error", message: "No window selected. Please select a window to record.")
                    return
                }
            case .area:
                guard selectedScreen != nil else {
                    showAlert(title: "Recording Error", message: "No display selected for area recording. Please select a display first.")
                    return
                }
                
                guard recordingArea != nil else {
                    showAlert(title: "Recording Error", message: "No area selected. Please use the 'Select Area...' button to choose an area to record.")
                    return
                }
            }
            
            // Initialize recording state
            isRecording = true
            startTime = Date()
            
            // Set up timer for recording duration
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.recordingDuration = Date().timeIntervalSince(self.startTime ?? Date())
                }
            }
            
            // Set up capture session with comprehensive error handling
            try await setupCaptureSession()
            
            // Start input tracking if enabled
            startInputTracking()
        } catch {
            // Handle any errors during recording setup
            print("Error starting recording: \(error)")
            isRecording = false
            timer?.invalidate()
            timer = nil
            recordingDuration = 0
            
            // Show error to user
            await MainActor.run {
                showAlert(title: "Recording Error", message: "Could not start recording: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func startInputTracking() {
        // Check if mouse tracking is enabled
        if preferencesManager?.recordMouseMovements == true, let url = mouseTrackingURL {
            // Request accessibility permission if needed
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            let accessEnabled = AXIsProcessTrustedWithOptions(options)
            
            if accessEnabled {
                mouseTracker.startTracking(outputURL: url)
            } else {
                print("Mouse tracking requires Accessibility permission")
            }
        }
        
        // Check if keyboard tracking is enabled
        if preferencesManager?.recordKeystrokes == true, let url = keyboardTrackingURL {
            // Request accessibility permission if needed (already requested for mouse)
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
            let accessEnabled = AXIsProcessTrustedWithOptions(options)
            
            if accessEnabled {
                keyboardTracker.startTracking(outputURL: url, maskSensitive: true)
            } else {
                print("Keyboard tracking requires Accessibility permission")
            }
        }
    }
    
    @MainActor
    func stopRecording() async {
        guard isRecording else { return }
        
        do {
            // Update recording state
            isRecording = false
            isPaused = false
            timer?.invalidate()
            timer = nil
            recordingDuration = 0
            
            // Stop input tracking
            mouseTracker.stopTracking()
            keyboardTracker.stopTracking()
            
            // Teardown capture session
            try await teardownCaptureSession()
            
        } catch {
            print("Error stopping recording: \(error)")
            // Force reset of the recording state even if teardown fails
            isRecording = false
            isPaused = false
            timer?.invalidate()
            timer = nil
            recordingDuration = 0
            captureSession = nil
            videoAssetWriter = nil
            audioAssetWriter = nil
            videoInput = nil
            audioInput = nil
            videoOutputURL = nil
            audioOutputURL = nil
        }
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
    
    private func createOutputURLs() -> (videoURL: URL, audioURL: URL?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let baseName = "DidYouGetIt_\(timestamp)"
        let videoFileName = "\(baseName).mov"
        let audioFileName = "\(baseName)_audio.m4a"
        
        let documentsPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        
        // Create folder for this recording session
        let folderURL = documentsPath.appendingPathComponent(baseName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        // Create URLs for tracking data
        mouseTrackingURL = folderURL.appendingPathComponent("\(baseName)_mouse.json")
        keyboardTrackingURL = folderURL.appendingPathComponent("\(baseName)_keyboard.json")
        
        // Return video and optional audio URLs
        let videoURL = folderURL.appendingPathComponent(videoFileName)
        let audioURL = preferencesManager?.mixAudioWithVideo == false ? folderURL.appendingPathComponent(audioFileName) : nil
        
        return (videoURL, audioURL)
    }
    
    private func setupCaptureSession() async throws {
        // Create and validate output URLs
        let urls = createOutputURLs()
        videoOutputURL = urls.videoURL
        audioOutputURL = urls.audioURL
        
        guard let videoURL = videoOutputURL else {
            throw NSError(domain: "RecordingManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create video output URL"])
        }
        
        // Check and request audio permission if needed
        if await shouldRecordAudio() {
            let audioPermission = await AVCaptureDevice.requestAccess(for: .audio)
            if !audioPermission {
                print("Audio permission denied")
            }
        }
        
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
        
        // Configure audio capture if needed
        if await shouldRecordAudio() {
            streamConfig.capturesAudio = true
            // Configure audio settings - we'll use the system default microphone
            streamConfig.excludesCurrentProcessAudio = true
        }
        
        // Get the display or window to capture
        let contentFilter: SCContentFilter
        switch captureType {
        case .display:
            guard let display = selectedScreen else {
                throw NSError(domain: "RecordingManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No display selected"])
            }
            // Update configuration for display resolution
            let screenWidth = Int(display.frame.width)
            let screenHeight = Int(display.frame.height)
            let scale = 2 // Retina
            
            streamConfig.width = screenWidth * scale
            streamConfig.height = screenHeight * scale
            print("Capturing display at \(screenWidth * scale) x \(screenHeight * scale)")
            
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
            
        case .window:
            guard let window = selectedWindow else {
                throw NSError(domain: "RecordingManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
            }
            
            let windowWidth = Int(window.frame.width)
            let windowHeight = Int(window.frame.height)
            let scale = 2 // Retina
            
            streamConfig.width = windowWidth * scale
            streamConfig.height = windowHeight * scale
            print("Capturing window at \(windowWidth * scale) x \(windowHeight * scale)")
            
            contentFilter = SCContentFilter(desktopIndependentWindow: window)
            
        case .area:
            guard let display = selectedScreen, let area = recordingArea else {
                throw NSError(domain: "RecordingManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display or area selected"])
            }
            
            let areaWidth = Int(area.width)
            let areaHeight = Int(area.height)
            let scale = 2 // Retina
            
            // Important: The streamConfig dimensions MUST match the area or writer will fail silently
            streamConfig.width = areaWidth * scale
            streamConfig.height = areaHeight * scale
            print("Capturing area at \(areaWidth * scale) x \(areaHeight * scale)")
            
            // For area selection we need a more specific content filter
            let rect = CGRect(x: area.origin.x, y: area.origin.y, width: area.width, height: area.height)
            print("Area coords: \(rect.origin.x), \(rect.origin.y), \(rect.width), \(rect.height)")
            
            // Create filter with region
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
        }
        
        // Create the stream
        captureSession = SCStream(filter: contentFilter, configuration: streamConfig, delegate: nil)
        
        // Make sure existing files at destination URLs are removed to avoid collision issues
        // This ensures we have a clean slate for writing
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: videoURL.path) {
            do {
                try fileManager.removeItem(at: videoURL)
            } catch {
                print("Warning: Could not remove existing file at \(videoURL.path): \(error)")
            }
        }
        
        if let audioURL = audioOutputURL, fileManager.fileExists(atPath: audioURL.path) {
            do {
                try fileManager.removeItem(at: audioURL)
            } catch {
                print("Warning: Could not remove existing file at \(audioURL.path): \(error)")
            }
        }
        
        // Set up video asset writer
        videoAssetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
        
        // Set up separate audio asset writer if needed
        if let audioURL = audioOutputURL {
            audioAssetWriter = try AVAssetWriter(outputURL: audioURL, fileType: .m4a)
        }
        
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
        guard let videoInput = videoInput else {
            throw NSError(domain: "RecordingManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Failed to create video input"])
        }
        
        videoInput.expectsMediaDataInRealTime = true
        
        guard let videoWriter = videoAssetWriter, videoWriter.canAdd(videoInput) else {
            throw NSError(domain: "RecordingManager", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to asset writer"])
        }
        
        videoWriter.add(videoInput)
        
        // Set up audio input if needed
        if await shouldRecordAudio() {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100.0,
                AVEncoderBitRateKey: 128000
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            
            if let audioInput = audioInput {
                audioInput.expectsMediaDataInRealTime = true
                
                if preferencesManager?.mixAudioWithVideo == true {
                    // Add audio to video file
                    if videoWriter.canAdd(audioInput) {
                        videoWriter.add(audioInput)
                    } else {
                        print("Warning: Cannot add audio input to video asset writer")
                    }
                } else if let audioAssetWriter = audioAssetWriter {
                    // Add audio to separate file
                    if audioAssetWriter.canAdd(audioInput) {
                        audioAssetWriter.add(audioInput)
                    } else {
                        print("Warning: Cannot add audio input to audio asset writer")
                    }
                }
            }
        }
        
        // Start asset writers
        videoWriter.startWriting()
        
        if let audioAssetWriter = audioAssetWriter {
            audioAssetWriter.startWriting()
        }
        
        // Start capturing
        try await startCapture()
    }
    
    private func startCapture() async throws {
        guard let stream = captureSession else {
            throw NSError(domain: "RecordingManager", code: 1010, userInfo: [NSLocalizedDescriptionKey: "No capture session available"])
        }
        
        // Reset diagnostic counters
        videoFramesProcessed = 0
        audioSamplesProcessed = 0
        
        // Ensure writers are ready before starting capture
        guard let videoWriter = videoAssetWriter, videoWriter.status == .writing else {
            throw NSError(domain: "RecordingManager", code: 1011, userInfo: [NSLocalizedDescriptionKey: "Video asset writer is not ready for writing"])
        }
        
        if let audioWriter = audioAssetWriter {
            guard audioWriter.status == .writing else {
                throw NSError(domain: "RecordingManager", code: 1012, userInfo: [NSLocalizedDescriptionKey: "Audio asset writer is not ready for writing"])
            }
        }
        
        print("Starting capture with writers prepared...")
        
        // Create a handler for the stream frames
        let handler: (CMSampleBuffer, SCStreamType) -> Void = { [weak self] sampleBuffer, type in
            guard let self = self, !self.isPaused else { return }
            
            switch type {
            case .screen:
                self.processSampleBuffer(sampleBuffer)
            case .audio:
                self.processAudioSampleBuffer(sampleBuffer)
            @unknown default:
                break
            }
        }
        
        // Create output with handler
        let output = SCStreamFrameOutput(handler: handler)
        
        // Create dedicated dispatch queues with high QoS to ensure performance
        let screenQueue = DispatchQueue(label: "it.didyouget.screenCaptureQueue", qos: .userInteractive)
        let audioQueue = DispatchQueue(label: "it.didyouget.audioCaptureQueue", qos: .userInteractive)
        
        // Add screen output on the dedicated queue
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: screenQueue)
        print("Screen capture output added successfully")
        
        // Add audio output if needed on separate queue
        if await shouldRecordAudio() {
            // Add microphone output
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
            print("Audio capture output added successfully")
        }
        
        // Start stream capture
        print("Starting SCStream capture...")
        try await stream.startCapture()
        print("SCStream capture started successfully")
        
        // Start writer sessions
        videoWriter.startSession(atSourceTime: .zero)
        print("Video writer session started at time zero")
        
        if let audioWriter = audioAssetWriter {
            audioWriter.startSession(atSourceTime: .zero)
            print("Audio writer session started at time zero")
        }
    }
    
    @MainActor
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Completely skip processing if we're paused
        guard !isPaused else { return }
        
        // Before using a potentially less reliable buffer, validate it
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Sample buffer data is not ready")
            return
        }
        
        // Access these properties on the main actor
        guard let videoInput = videoInput,
              let writer = videoAssetWriter,
              writer.status == .writing,
              videoInput.isReadyForMoreMediaData else { return }
        
        // Get timing info from the sample buffer
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                return
            }
        }
        
        // Append the buffer
        let success = videoInput.append(sampleBuffer)
        
        if !success {
            print("WARNING: Failed to append video sample buffer")
        } else {
            // Keep track of processed frames for diagnostics
            videoFramesProcessed += 1
        }
    }
    
    @MainActor
    private func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Skip processing if paused
        guard !isPaused else { return }
        
        // Validate the sample buffer
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Audio sample buffer data is not ready")
            return
        }
        
        // Access properties directly on the main actor
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else { return }
        
        // Check for discontinuity flags
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                return
            }
        }
        
        // Get the mixing preference from the current state
        let isMixingAudio = preferencesManager?.mixAudioWithVideo ?? false
        
        var success = false
        
        // Check if we're mixing or using separate files
        if isMixingAudio || audioAssetWriter == nil {
            // Mixed with video or no separate audio writer
            if let writer = videoAssetWriter, writer.status == .writing {
                success = audioInput.append(sampleBuffer)
            }
        } else {
            // Writing to separate file
            if let writer = audioAssetWriter, writer.status == .writing {
                success = audioInput.append(sampleBuffer)
            }
        }
        
        if !success {
            print("WARNING: Failed to append audio sample buffer")
        } else {
            // Track processed samples for diagnostics
            audioSamplesProcessed += 1
        }
    }
    
    private func shouldRecordAudio() async -> Bool {
        // Get the preference from the PreferencesManager
        return await MainActor.run {
            let preferencesManager = getPreferencesManager()
            return preferencesManager?.recordAudio ?? false
        }
    }
    
    
    private var preferencesManager: PreferencesManager?
    
    func setPreferencesManager(_ manager: PreferencesManager) {
        preferencesManager = manager
    }
    
    private func getPreferencesManager() -> PreferencesManager? {
        return preferencesManager
    }
    
    private func teardownCaptureSession() async throws {
        // Create a copy of URLs for verification
        let videoURL = videoOutputURL
        let audioURL = audioOutputURL
        let mouseURL = mouseTrackingURL
        let keyboardURL = keyboardTrackingURL
        
        print("Stopping recording session and processing files...")
        
        // Stop capture stream first
        if let stream = captureSession {
            do {
                try await stream.stopCapture()
                print("Stream capture stopped successfully")
            } catch {
                print("Error stopping capture stream: \(error)")
                // Continue with teardown even if stopCapture fails
            }
        }
        
        // Add a slight delay to ensure all buffers are flushed
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mark inputs as finished
        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }
        
        if let audioInput = audioInput {
            audioInput.markAsFinished()
        }
        
        print("Inputs marked as finished, finalizing files...")
        
        // Add another brief delay to ensure processing completes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Finish writing to output files
        var videoWriteError: Error? = nil
        var audioWriteError: Error? = nil
        
        if let writer = videoAssetWriter {
            await writer.finishWriting()
            if writer.status == .failed {
                videoWriteError = writer.error
                print("Video asset writer failed: \(String(describing: writer.error))")
            } else {
                print("Video successfully finalized")
            }
        }
        
        if let audioWriter = audioAssetWriter {
            await audioWriter.finishWriting()
            if audioWriter.status == .failed {
                audioWriteError = audioWriter.error
                print("Audio asset writer failed: \(String(describing: audioWriter.error))")
            } else {
                print("Audio successfully finalized")
            }
        }
        
        // Verify output files
        await verifyOutputFiles(videoURL: videoURL, audioURL: audioURL, mouseURL: mouseURL, keyboardURL: keyboardURL)
        
        // Clean up resources
        captureSession = nil
        videoAssetWriter = nil
        audioAssetWriter = nil
        videoInput = nil
        audioInput = nil
        
        // Release the URLs
        videoOutputURL = nil
        audioOutputURL = nil
        
        // Report any errors that occurred during finishWriting
        if let error = videoWriteError ?? audioWriteError {
            throw error
        }
    }
    
    private func verifyOutputFiles(videoURL: URL?, audioURL: URL?, mouseURL: URL?, keyboardURL: URL?) async {
        print("\nRecording diagnostics:")
        print("Video frames processed: \(videoFramesProcessed)")
        print("Audio samples processed: \(audioSamplesProcessed)")
        
        // Check file existence and size
        if let url = videoURL, FileManager.default.fileExists(atPath: url.path) {
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 {
                print("Video file size: \(fileSize) bytes")
                if fileSize == 0 {
                    print("WARNING: Video file is zero bytes despite processing \(videoFramesProcessed) frames!")
                    print("Make sure: 1) file paths are correct 2) all sample buffers are valid 3) writer properly started")
                    print("Zero-length file usually means the writer didn't receive any valid input or wasn't properly initialized")
                } else if fileSize < 1000 {
                    print("WARNING: Video file is very small (\(fileSize) bytes) - recording may be incomplete")
                }
            } else {
                print("WARNING: Unable to determine video file size")
            }
        } else if videoURL != nil {
            print("WARNING: Video file not found at expected location: \(videoURL?.path ?? "unknown")")
        }
        
        if let url = audioURL, FileManager.default.fileExists(atPath: url.path) {
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 {
                print("Audio file size: \(fileSize) bytes")
                if fileSize == 0 {
                    print("WARNING: Audio file is zero bytes despite processing \(audioSamplesProcessed) samples!")
                } else if fileSize < 1000 {
                    print("WARNING: Audio file is very small (\(fileSize) bytes) - recording may be incomplete")
                }
            } else {
                print("WARNING: Unable to determine audio file size")
            }
        } else if audioURL != nil && preferencesManager?.recordAudio == true && preferencesManager?.mixAudioWithVideo == false {
            print("WARNING: Audio file not found at expected location: \(audioURL?.path ?? "unknown")")
        }
        
        // Check input tracking files
        if let url = mouseURL, FileManager.default.fileExists(atPath: url.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                print("Mouse tracking file size: \(size) bytes")
                if size == 0 {
                    print("WARNING: Mouse tracking file is empty")
                }
            } else {
                print("WARNING: Unable to determine mouse tracking file size")
            }
        } else if preferencesManager?.recordMouseMovements == true {
            print("WARNING: Mouse tracking file not found at expected location: \(mouseURL?.path ?? "unknown")")
        }
        
        if let url = keyboardURL, FileManager.default.fileExists(atPath: url.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? UInt64 {
                print("Keyboard tracking file size: \(size) bytes")
                if size == 0 {
                    print("WARNING: Keyboard tracking file is empty")
                }
            } else {
                print("WARNING: Unable to determine keyboard tracking file size")
            }
        } else if preferencesManager?.recordKeystrokes == true {
            print("WARNING: Keyboard tracking file not found at expected location: \(keyboardURL?.path ?? "unknown")")
        }
    }
}