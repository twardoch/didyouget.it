import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import ObjectiveC

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
            streamConfig.width = Int(display.frame.width) * 2 // Retina
            streamConfig.height = Int(display.frame.height) * 2 // Retina
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
        case .window:
            guard let window = selectedWindow else {
                throw NSError(domain: "RecordingManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
            }
            contentFilter = SCContentFilter(desktopIndependentWindow: window)
        case .area:
            guard let display = selectedScreen, let area = recordingArea else {
                throw NSError(domain: "RecordingManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display or area selected"])
            }
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
            streamConfig.width = Int(area.width) * 2 // Retina
            streamConfig.height = Int(area.height) * 2 // Retina
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
        
        // Ensure writers are ready before starting capture
        guard let videoWriter = videoAssetWriter, videoWriter.status == .writing else {
            throw NSError(domain: "RecordingManager", code: 1011, userInfo: [NSLocalizedDescriptionKey: "Video asset writer is not ready for writing"])
        }
        
        if let audioWriter = audioAssetWriter {
            guard audioWriter.status == .writing else {
                throw NSError(domain: "RecordingManager", code: 1012, userInfo: [NSLocalizedDescriptionKey: "Audio asset writer is not ready for writing"])
            }
        }
        
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
        
        // Create a dedicated dispatch queue with quality of service to ensure consistent performance
        let screenQueue = DispatchQueue(label: "it.didyouget.screenCaptureQueue", qos: .userInitiated)
        let audioQueue = DispatchQueue(label: "it.didyouget.audioCaptureQueue", qos: .userInitiated)
        
        // Add screen output on the dedicated queue
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: screenQueue)
        
        // Add audio output if needed on separate queue
        if await shouldRecordAudio() {
            // Add microphone output
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
        }
        
        // Start stream capture
        try await stream.startCapture()
        
        // Start writer sessions
        videoWriter.startSession(atSourceTime: .zero)
        audioAssetWriter?.startSession(atSourceTime: .zero)
    }
    
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Completely skip processing if we're paused
        guard !isPaused else { return }
        
        // Before using a potentially less reliable buffer, validate it
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Sample buffer data is not ready")
            return
        }
        
        // Move the processing to the main thread to ensure we're not dealing with background thread issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  !self.isPaused,
                  let videoInput = self.videoInput,
                  let writer = self.videoAssetWriter,
                  writer.status == .writing,
                  videoInput.isReadyForMoreMediaData else { return }
            
            // Use a synchronized block when appending
            objc_sync_enter(videoInput)
            videoInput.append(sampleBuffer)
            objc_sync_exit(videoInput)
        }
    }
    
    private func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Skip processing if paused
        guard !isPaused else { return }
        
        // Validate the sample buffer
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("Audio sample buffer data is not ready")
            return
        }
        
        // Process on the main thread to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  !self.isPaused,
                  let audioInput = self.audioInput,
                  audioInput.isReadyForMoreMediaData else { return }
            
            // Get the mixing preference from the current state
            let isMixingAudio = self.preferencesManager?.mixAudioWithVideo ?? false
            
            // Using a synchronized block for thread safety
            objc_sync_enter(audioInput)
            
            // Check if we're mixing or using separate files
            if isMixingAudio || self.audioAssetWriter == nil {
                // Mixed with video or no separate audio writer
                if let writer = self.videoAssetWriter, writer.status == .writing {
                    audioInput.append(sampleBuffer)
                }
            } else {
                // Writing to separate file
                if let writer = self.audioAssetWriter, writer.status == .writing {
                    audioInput.append(sampleBuffer)
                }
            }
            
            objc_sync_exit(audioInput)
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
        // Stop capture stream first
        if let stream = captureSession {
            do {
                try await stream.stopCapture()
            } catch {
                print("Error stopping capture stream: \(error)")
                // Continue with teardown even if stopCapture fails
            }
        }
        
        // Mark inputs as finished
        if let videoInput = videoInput {
            videoInput.markAsFinished()
        }
        
        if let audioInput = audioInput {
            audioInput.markAsFinished()
        }
        
        // Finish writing to output files
        var videoWriteError: Error? = nil
        var audioWriteError: Error? = nil
        
        if let writer = videoAssetWriter {
            await writer.finishWriting()
            if writer.status == .failed {
                videoWriteError = writer.error
                print("Video asset writer failed: \(String(describing: writer.error))")
            }
        }
        
        if let audioWriter = audioAssetWriter {
            await audioWriter.finishWriting()
            if audioWriter.status == .failed {
                audioWriteError = audioWriter.error
                print("Audio asset writer failed: \(String(describing: audioWriter.error))")
            }
        }
        
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
}