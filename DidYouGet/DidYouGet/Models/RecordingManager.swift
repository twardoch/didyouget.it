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
                print("SCStream output: Received screen frame")
                handler(sampleBuffer, .screen)
            case .audio:
                print("SCStream output: Received audio sample")
                handler(sampleBuffer, .audio)
            case .microphone:
                print("SCStream output: Received microphone sample")
                handler(sampleBuffer, .audio)
            @unknown default:
                print("SCStream output: Received unknown type \(type)")
                break
            }
        }
    }
    
    init() {
        print("Initializing RecordingManager")
        
        // Delay permissions check to avoid initialization crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkPermissions()
            
            // Load content after permissions check
            Task { [weak self] in
                await self?.loadAvailableContent()
            }
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
        do {
            try await startRecordingAsync()
        } catch {
            print("Error in startRecording: \(error)")
            // Reset state
            isRecording = false
            timer?.invalidate()
            timer = nil
            recordingDuration = 0
            
            // Show error to user
            showAlert(title: "Recording Error", message: error.localizedDescription)
        }
    }
    
    @MainActor
    func startRecordingAsync() async throws {
        // Reset any existing recording state first
        await resetRecordingState()
        
        print("\n=== STARTING RECORDING ===\n")
        
        // Check if we have all the required parameters before starting
        switch captureType {
        case .display:
            guard selectedScreen != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No display selected for display recording")
                throw NSError(domain: "RecordingManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No display selected. Please select a display to record."])
            }
            print("Recording source: Display with ID \(selectedScreen!.displayID)")
            
        case .window:
            guard selectedWindow != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No window selected for window recording")
                throw NSError(domain: "RecordingManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No window selected. Please select a window to record."])
            }
            print("Recording source: Window with ID \(selectedWindow!.windowID) and title '\(selectedWindow!.title ?? "Untitled")'")
            
        case .area:
            guard selectedScreen != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No display selected for area recording")
                throw NSError(domain: "RecordingManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No display selected for area recording. Please select a display first."])
            }
            
            guard recordingArea != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No area selected for area recording")
                throw NSError(domain: "RecordingManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No area selected. Please use the 'Select Area...' button to choose an area to record."])
            }
            
            print("Recording source: Area \(Int(recordingArea!.width))×\(Int(recordingArea!.height)) at position (\(Int(recordingArea!.origin.x)), \(Int(recordingArea!.origin.y))) on display \(selectedScreen!.displayID)")
        }
        
        // Check preferences and connectivity
        guard let preferences = preferencesManager else {
            isRecording = false // Reset flag if we fail
            print("ERROR: PreferencesManager is not set")
            throw NSError(domain: "RecordingManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Internal error: preferences not available."])
        }
        
        print("Recording options: Audio=\(preferences.recordAudio), Mouse=\(preferences.recordMouseMovements), Keyboard=\(preferences.recordKeystrokes)")
        
        // Initialize recording state counters
        print("Setting up recording state")
        videoFramesProcessed = 0
        audioSamplesProcessed = 0

        do {
            // Set up capture session with comprehensive error handling
            print("Setting up capture session")
            try await setupCaptureSession()

            // Record start time only after capture starts
            startTime = Date()
            let startTimeCapture = startTime ?? Date()
            print("Starting recording timer at: \(startTimeCapture)")
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                let currentTime = Date()
                let duration = currentTime.timeIntervalSince(startTimeCapture)

                Task { @MainActor in
                    self.recordingDuration = duration
                }
            }

            self.timer = timer

            // Start input tracking if enabled
            print("Starting input tracking")
            startInputTracking()

            // Set recording state to true ONLY after all setup is complete
            isRecording = true

            print("Recording started successfully")
        } catch {
            // If we hit any errors, reset the recording state
            print("ERROR: Failed during recording setup: \(error)")
            await resetRecordingState()
            throw error
        }
    }
    
    @MainActor
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func startInputTracking() {
        // Check if preferences are available
        guard let preferences = preferencesManager else {
            print("ERROR: Cannot start input tracking - PreferencesManager is nil")
            return
        }
        
        // Request accessibility permission if needed for either tracking
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        // Log accessibility status
        print("Accessibility permission status: \(accessEnabled ? "Granted" : "Denied")")
        
        // Check if mouse tracking is enabled
        if preferences.recordMouseMovements, let url = mouseTrackingURL {
            print("Mouse tracking enabled, URL: \(url.path)")
            
            if accessEnabled {
                print("Starting mouse tracking")
                mouseTracker.startTracking(outputURL: url)
            } else {
                print("WARNING: Mouse tracking requires Accessibility permission - not starting")
            }
        } else {
            print("Mouse tracking disabled or no URL available")
        }
        
        // Check if keyboard tracking is enabled
        if preferences.recordKeystrokes, let url = keyboardTrackingURL {
            print("Keyboard tracking enabled, URL: \(url.path)")
            
            if accessEnabled {
                print("Starting keyboard tracking")
                keyboardTracker.startTracking(outputURL: url, maskSensitive: true)
            } else {
                print("WARNING: Keyboard tracking requires Accessibility permission - not starting")
            }
        } else {
            print("Keyboard tracking disabled or no URL available")
        }
    }
    
    @MainActor
    func stopRecording() async {
        do {
            try await stopRecordingAsync()
        } catch {
            print("Error in stopRecording: \(error)")
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
    func stopRecordingAsync() async throws {
        guard isRecording else { 
            print("Not recording, ignoring stop request")
            return 
        }
        
        print("\n=== STOPPING RECORDING ===\n")
        
        // Update recording state first to prevent UI from triggering multiple stops
        isRecording = false
        isPaused = false
        timer?.invalidate()
        timer = nil
        recordingDuration = 0
        
        // Stop input tracking
        print("Stopping input tracking")
        mouseTracker.stopTracking()
        keyboardTracker.stopTracking()
        
        // Teardown capture session
        print("Tearing down capture session")
        try await teardownCaptureSession()
        
        print("Recording stopped successfully")
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
        print("Base output directory: \(documentsPath.path)")
        
        // Create folder for this recording session
        let folderURL = documentsPath.appendingPathComponent(baseName, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            print("Created recording directory: \(folderURL.path)")
        } catch {
            print("ERROR: Failed to create recording directory: \(error)")
        }
        
        // Create URLs for tracking data
        let mouseTrackingPath = folderURL.appendingPathComponent("\(baseName)_mouse.json")
        let keyboardTrackingPath = folderURL.appendingPathComponent("\(baseName)_keyboard.json")
        
        print("Mouse tracking path: \(mouseTrackingPath.path)")
        print("Keyboard tracking path: \(keyboardTrackingPath.path)")
        
        mouseTrackingURL = mouseTrackingPath
        keyboardTrackingURL = keyboardTrackingPath
        
        // Return video and optional audio URLs
        let videoURL = folderURL.appendingPathComponent(videoFileName)
        print("Video output path: \(videoURL.path)")
        
        let audioURL: URL?
        if let preferences = preferencesManager, !preferences.mixAudioWithVideo && preferences.recordAudio {
            audioURL = folderURL.appendingPathComponent(audioFileName)
            print("Separate audio output path: \(audioURL?.path ?? "nil")")
        } else {
            audioURL = nil
            print("No separate audio file will be created (mixed with video or audio disabled)")
        }
        
        return (videoURL, audioURL)
    }
    
    private func setupCaptureSession() async throws {
        print("Setting up capture session...")
        
        // Create and validate output URLs
        let urls = createOutputURLs()
        videoOutputURL = urls.videoURL
        audioOutputURL = urls.audioURL
        
        guard let videoURL = videoOutputURL else {
            print("ERROR: Failed to create video output URL")
            throw NSError(domain: "RecordingManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create video output URL"])
        }
        
        // Check and request audio permission if needed
        let shouldRecordAudio = preferencesManager?.recordAudio == true
        if shouldRecordAudio {
            print("Audio recording is enabled, requesting permissions...")
            let audioPermission = await AVCaptureDevice.requestAccess(for: .audio)
            if !audioPermission {
                print("WARNING: Audio permission denied")
            } else {
                print("Audio permission granted")
            }
        } else {
            print("Audio recording is disabled")
        }
        
        // Get the content to capture
        print("Refreshing available content...")
        _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Create stream configuration
        print("Configuring stream settings...")
        let streamConfig = SCStreamConfiguration()
        streamConfig.queueDepth = 5 // Increase queue depth for smoother capture
        
        // Set initial dimensions to HD as default
        streamConfig.width = 1920
        streamConfig.height = 1080
        
        // Set frame rate based on preferences
        let frameRate = preferencesManager?.frameRate ?? 60
        print("Setting frame rate to \(frameRate) FPS")
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // Configure pixel format (BGRA is standard for macOS screen capture)
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.scalesToFit = true
        
        // Set aspect ratio preservation if available
        if #available(macOS 14.0, *) {
            streamConfig.preservesAspectRatio = true
            print("Aspect ratio preservation enabled (macOS 14+)")
        } else {
            print("Aspect ratio preservation not available (requires macOS 14+)")
        }
        
        // Configure audio capture if needed
        if preferencesManager?.recordAudio == true {
            print("Configuring audio capture...")
            streamConfig.capturesAudio = true
            
            // Configure audio settings - exclude app's own audio
            streamConfig.excludesCurrentProcessAudio = true
            print("Audio capture enabled, excluding current process audio")
        }
        
        // Get the display or window to capture
        print("Setting up content filter based on capture type: \(captureType)")
        let contentFilter: SCContentFilter
        switch captureType {
        case .display:
            guard let display = selectedScreen else {
                print("ERROR: No display selected for display capture")
                throw NSError(domain: "RecordingManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No display selected"])
            }
            
            // Update configuration for display resolution with Retina support
            let screenWidth = Int(display.frame.width)
            let screenHeight = Int(display.frame.height)
            let scale = 2 // Retina scale factor
            
            streamConfig.width = screenWidth * scale
            streamConfig.height = screenHeight * scale
            print("Capturing display \(display.displayID) at \(screenWidth * scale) x \(screenHeight * scale) (with Retina scaling)")
            
            // Create content filter for the display with no window exclusions
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
            
        case .window:
            guard let window = selectedWindow else {
                print("ERROR: No window selected for window capture")
                throw NSError(domain: "RecordingManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
            }
            
            let windowWidth = Int(window.frame.width)
            let windowHeight = Int(window.frame.height)
            let scale = 2 // Retina scale factor
            
            streamConfig.width = windowWidth * scale
            streamConfig.height = windowHeight * scale
            print("Capturing window '\(window.title ?? "Untitled")' at \(windowWidth * scale) x \(windowHeight * scale) (with Retina scaling)")
            
            // Create content filter for the specific window
            contentFilter = SCContentFilter(desktopIndependentWindow: window)
            
        case .area:
            guard let display = selectedScreen, let area = recordingArea else {
                print("ERROR: No display or area selected for area capture")
                throw NSError(domain: "RecordingManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display or area selected"])
            }
            
            let areaWidth = Int(area.width)
            let areaHeight = Int(area.height)
            let scale = 2 // Retina scale factor
            
            // IMPORTANT: The streamConfig dimensions MUST match the area for proper recording
            streamConfig.width = areaWidth * scale
            streamConfig.height = areaHeight * scale
            print("Capturing area at \(areaWidth * scale) x \(areaHeight * scale) (with Retina scaling)")
            
            // For area selection we need a specific content filter
            let rect = CGRect(x: area.origin.x, y: area.origin.y, width: area.width, height: area.height)
            print("Area coordinates: (\(Int(rect.origin.x)), \(Int(rect.origin.y))) with size \(Int(rect.width))×\(Int(rect.height))")
            
            // For capture areas, we need to capture the whole display and then crop
            // in the video settings to the area we want
            contentFilter = SCContentFilter(display: display, excludingWindows: [])
            print("Using full display filter with area cropping")
        }
        
        // Create the stream with the configured filter and settings
        print("Creating SCStream with configured filter and settings")
        captureSession = SCStream(filter: contentFilter, configuration: streamConfig, delegate: nil)
        
        // Make sure existing files at destination URLs are removed to avoid collision issues
        // This ensures we have a clean slate for writing
        print("Checking for existing files at destination paths")
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: videoURL.path) {
            print("Found existing video file, removing: \(videoURL.path)")
            do {
                try fileManager.removeItem(at: videoURL)
                print("Successfully removed existing video file")
            } catch {
                print("WARNING: Could not remove existing file at \(videoURL.path): \(error)")
            }
        }
        
        if let audioURL = audioOutputURL, fileManager.fileExists(atPath: audioURL.path) {
            print("Found existing audio file, removing: \(audioURL.path)")
            do {
                try fileManager.removeItem(at: audioURL)
                print("Successfully removed existing audio file")
            } catch {
                print("WARNING: Could not remove existing file at \(audioURL.path): \(error)")
            }
        }
        
        // Set up video asset writer
        print("Creating video asset writer with output URL: \(videoURL.path)")
        do {
            videoAssetWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mov)
            print("Video asset writer created successfully")
        } catch {
            print("ERROR: Failed to create video asset writer: \(error)")
            throw error
        }
        
        // Set up separate audio asset writer if needed
        if let audioURL = audioOutputURL {
            print("Creating separate audio asset writer with output URL: \(audioURL.path)")
            do {
                audioAssetWriter = try AVAssetWriter(outputURL: audioURL, fileType: .m4a)
                print("Audio asset writer created successfully")
            } catch {
                print("ERROR: Failed to create audio asset writer: \(error)")
                throw error
            }
        }
        
        // Configure video input with settings
        print("Configuring video input settings")
        
        // Get video quality settings from preferences
        let videoQuality = preferencesManager?.videoQuality ?? .high
        let bitrate: Int
        
        // Scale bitrate based on resolution and quality setting
        switch videoQuality {
        case .low:
            bitrate = 5_000_000 // 5 Mbps
        case .medium:
            bitrate = 10_000_000 // 10 Mbps
        case .high:
            bitrate = 20_000_000 // 20 Mbps
        case .lossless:
            bitrate = 50_000_000 // 50 Mbps
        }
        
        print("Using video quality: \(videoQuality.rawValue) with bitrate: \(bitrate/1_000_000) Mbps")
        
        // Configure video settings with appropriate parameters
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: streamConfig.width,
            AVVideoHeightKey: streamConfig.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalKey: frameRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        // For area captures, log info about settings
        if captureType == .area, let area = recordingArea {
            print("Video settings for area capture: width=\(streamConfig.width), height=\(streamConfig.height)")
            print("Selected area: \(Int(area.width)) x \(Int(area.height)) at (\(Int(area.origin.x)), \(Int(area.origin.y)))")
        }
        
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
        if preferencesManager?.recordAudio == true {
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
            guard let self = self else { 
                print("ERROR: Self is nil in stream handler")
                return 
            }
            
            if self.isPaused {
                print("Recording is paused, skipping frame processing")
                return
            }
            
            // Use Task to dispatch back to the main actor
            Task { @MainActor in
                switch type {
                case .screen:
                    print("Processing screen frame")
                    self.processSampleBuffer(sampleBuffer)
                case .audio:
                    print("Processing audio sample")
                    self.processAudioSampleBuffer(sampleBuffer)
                @unknown default:
                    print("Unknown sample type, cannot process")
                    break
                }
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
        if preferencesManager?.recordAudio == true {
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
        // Completely skip processing if we're paused or not recording
        guard isRecording && !isPaused else { return }
        
        // Before using a potentially less reliable buffer, validate it
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("ERROR: Sample buffer data is not ready")
            return
        }
        
        // Access these properties on the main actor
        guard let videoInput = videoInput else {
            print("ERROR: Video input is nil")
            return
        }
        
        guard let writer = videoAssetWriter else {
            print("ERROR: Video asset writer is nil")
            return
        }
        
        guard writer.status == .writing else {
            print("ERROR: Writer is not in writing state. Current state: \(writer.status.rawValue)")
            return
        }
        
        guard videoInput.isReadyForMoreMediaData else {
            print("WARNING: Video input is not ready for more data")
            return
        }
        
        // Get timing info from the sample buffer
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                print("WARNING: Skipping discontinuous sample buffer")
                return
            }
        }
        
        // Append the buffer
        let success = videoInput.append(sampleBuffer)
        
        if !success {
            print("ERROR: Failed to append video sample buffer")
        } else {
            // Keep track of processed frames for diagnostics
            videoFramesProcessed += 1
            if videoFramesProcessed % 60 == 0 {
                print("Processed \(videoFramesProcessed) video frames so far")
            }
        }
    }
    
    @MainActor
    private func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        // Skip processing if paused or not recording
        guard isRecording && !isPaused else { return }
        
        // Validate the sample buffer
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("ERROR: Audio sample buffer data is not ready")
            return
        }
        
        // Access properties directly on the main actor
        guard let audioInput = audioInput else {
            print("ERROR: Audio input is nil")
            return
        }
        
        guard audioInput.isReadyForMoreMediaData else {
            print("WARNING: Audio input is not ready for more data")
            return
        }
        
        // Check for discontinuity flags
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                print("WARNING: Skipping discontinuous audio sample buffer")
                return
            }
        }
        
        // Get the mixing preference from the current state
        guard let preferences = preferencesManager else {
            print("ERROR: PreferencesManager is nil")
            return
        }
        
        let isMixingAudio = preferences.mixAudioWithVideo
        
        var success = false
        
        // Check if we're mixing or using separate files
        if isMixingAudio || audioAssetWriter == nil {
            // Mixed with video or no separate audio writer
            if let writer = videoAssetWriter, writer.status == .writing {
                success = audioInput.append(sampleBuffer)
            } else {
                print("ERROR: Cannot append audio to video - writer not ready")
            }
        } else {
            // Writing to separate file
            if let writer = audioAssetWriter, writer.status == .writing {
                success = audioInput.append(sampleBuffer)
            } else {
                print("ERROR: Cannot append audio to separate file - writer not ready")
            }
        }
        
        if !success {
            print("ERROR: Failed to append audio sample buffer")
        } else {
            // Track processed samples for diagnostics
            audioSamplesProcessed += 1
            if audioSamplesProcessed % 100 == 0 {
                print("Processed \(audioSamplesProcessed) audio samples so far")
            }
        }
    }
    
    private var preferencesManager: PreferencesManager?
    
    func setPreferencesManager(_ manager: PreferencesManager) {
        preferencesManager = manager
    }
    
    private func getPreferencesManager() -> PreferencesManager? {
        return preferencesManager
    }
    
    @MainActor
    func resetRecordingState() async {
        print("Resetting recording state")
        
        // Reset recording flags
        isRecording = false
        isPaused = false
        recordingDuration = 0
        
        // Invalidate timers
        timer?.invalidate()
        timer = nil
        
        // Reset writer objects
        captureSession = nil
        videoAssetWriter = nil
        audioAssetWriter = nil
        videoInput = nil
        audioInput = nil
        
        // Reset URLs
        videoOutputURL = nil
        audioOutputURL = nil
        mouseTrackingURL = nil
        keyboardTrackingURL = nil
        
        // Reset counters
        videoFramesProcessed = 0
        audioSamplesProcessed = 0
        
        // Reset start time
        startTime = nil
        
        print("Recording state reset complete")
    }
    
    private func teardownCaptureSession() async throws {
        print("\n=== STOPPING RECORDING ===\n")
        
        // Create a copy of URLs for verification
        let videoURL = videoOutputURL
        let audioURL = audioOutputURL
        let mouseURL = mouseTrackingURL
        let keyboardURL = keyboardTrackingURL
        
        print("Stopping recording session and processing files...")
        print("Video frames processed during session: \(videoFramesProcessed)")
        print("Audio samples processed during session: \(audioSamplesProcessed)")
        
        // Stop capture stream first
        if let stream = captureSession {
            do {
                print("Stopping SCStream capture...")
                try await stream.stopCapture()
                print("Stream capture stopped successfully")
            } catch {
                print("ERROR: Error stopping capture stream: \(error)")
                print("Continuing with teardown despite stream stop error")
                // Continue with teardown even if stopCapture fails
            }
        } else {
            print("WARNING: No capture session to stop")
        }
        
        // Add a slight delay to ensure all buffers are flushed
        print("Waiting for buffers to flush...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mark inputs as finished
        if let videoInput = videoInput {
            print("Marking video input as finished")
            videoInput.markAsFinished()
        } else {
            print("WARNING: No video input to mark as finished")
        }
        
        if let audioInput = audioInput {
            print("Marking audio input as finished")
            audioInput.markAsFinished()
        } else {
            print("No audio input to mark as finished")
        }
        
        print("Inputs marked as finished, waiting before finalizing files...")
        
        // Add another brief delay to ensure processing completes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Finish writing to output files
        var videoWriteError: Error? = nil
        var audioWriteError: Error? = nil
        
        if let writer = videoAssetWriter {
            print("Finalizing video file...")
            await writer.finishWriting()
            if writer.status == .failed {
                videoWriteError = writer.error
                print("ERROR: Video asset writer failed: \(String(describing: writer.error))")
            } else if writer.status == .completed {
                print("Video successfully finalized")
            } else {
                print("WARNING: Unexpected video writer status: \(writer.status.rawValue)")
            }
        } else {
            print("WARNING: No video asset writer to finalize")
        }
        
        if let audioWriter = audioAssetWriter {
            print("Finalizing audio file...")
            await audioWriter.finishWriting()
            if audioWriter.status == .failed {
                audioWriteError = audioWriter.error
                print("ERROR: Audio asset writer failed: \(String(describing: audioWriter.error))")
            } else if audioWriter.status == .completed {
                print("Audio successfully finalized")
            } else {
                print("WARNING: Unexpected audio writer status: \(audioWriter.status.rawValue)")
            }
        } else {
            print("No separate audio asset writer to finalize")
        }
        
        // Extra delay to ensure filesystem operations complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify output files
        print("Verifying output files...")
        await verifyOutputFiles(videoURL: videoURL, audioURL: audioURL, mouseURL: mouseURL, keyboardURL: keyboardURL)
        
        // Clean up resources
        print("Cleaning up resources...")
        captureSession = nil
        videoAssetWriter = nil
        audioAssetWriter = nil
        videoInput = nil
        audioInput = nil
        
        // Release the URLs
        videoOutputURL = nil
        audioOutputURL = nil
        mouseTrackingURL = nil
        keyboardTrackingURL = nil
        
        print("Recording cleanup complete")
        
        // Report any errors that occurred during finishWriting
        if let error = videoWriteError ?? audioWriteError {
            print("ERROR: Throwing error from teardown: \(error)")
            throw error
        }
    }
    
    private func verifyOutputFiles(videoURL: URL?, audioURL: URL?, mouseURL: URL?, keyboardURL: URL?) async {
        print("\n=== RECORDING DIAGNOSTICS ===\n")
        print("Video frames processed: \(videoFramesProcessed)")
        print("Audio samples processed: \(audioSamplesProcessed)")
        
        // Helper function to check file size and validity
        func checkFileStatus(url: URL?, fileType: String, expectedNonEmpty: Bool) {
            guard let url = url else {
                if expectedNonEmpty {
                    print("ERROR: \(fileType) URL is nil but was expected to be present")
                }
                return
            }
            
            print("Checking \(fileType) file: \(url.path)")
            
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attrs[.size] as? UInt64 {
                        print("\(fileType) file size: \(fileSize) bytes")
                        
                        if fileSize == 0 {
                            print("ERROR: \(fileType) file is empty (zero bytes)!")
                            if fileType == "Video" {
                                print("Common causes for empty video files:")
                                print("1. No valid frames were received from the capture source")
                                print("2. AVAssetWriter was not properly initialized or started")
                                print("3. Stream configuration doesn't match the actual content being captured")
                                print("4. There was an error in the capture/encoding pipeline")
                            }
                        } else if fileSize < 1000 && (fileType == "Video" || fileType == "Audio") {
                            print("WARNING: \(fileType) file is suspiciously small (\(fileSize) bytes)")
                        } else {
                            print("✓ \(fileType) file successfully saved with size: \(fileSize) bytes")
                        }
                    } else {
                        print("WARNING: Unable to read \(fileType) file size attribute")
                    }
                    
                    // Print creation date for debugging
                    if let creationDate = attrs[.creationDate] as? Date {
                        print("\(fileType) file created at: \(creationDate)")
                    }
                } catch {
                    print("ERROR: Failed to get \(fileType) file attributes: \(error)")
                }
            } else {
                if expectedNonEmpty {
                    print("ERROR: \(fileType) file not found at expected location: \(url.path)")
                } else {
                    print("\(fileType) file not created (not expected for this configuration)")
                }
            }
        }
        
        // Get preferences for expected files
        let preferences = preferencesManager
        let shouldHaveVideo = true // Video is always expected
        let shouldHaveSeparateAudio = preferences?.recordAudio == true && preferences?.mixAudioWithVideo == false
        let shouldHaveMouse = preferences?.recordMouseMovements == true
        let shouldHaveKeyboard = preferences?.recordKeystrokes == true
        
        // Check all output files
        checkFileStatus(url: videoURL, fileType: "Video", expectedNonEmpty: shouldHaveVideo)
        checkFileStatus(url: audioURL, fileType: "Audio", expectedNonEmpty: shouldHaveSeparateAudio)
        checkFileStatus(url: mouseURL, fileType: "Mouse tracking", expectedNonEmpty: shouldHaveMouse)
        checkFileStatus(url: keyboardURL, fileType: "Keyboard tracking", expectedNonEmpty: shouldHaveKeyboard)
        
        // If the video file is empty but we processed frames, something went wrong
        if videoFramesProcessed > 0 {
            if let url = videoURL, FileManager.default.fileExists(atPath: url.path) {
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64, fileSize == 0 {
                    print("\nCRITICAL ERROR: Processed \(videoFramesProcessed) frames but video file is empty!")
                    print("This indicates a serious issue with the AVAssetWriter configuration or initialization.")
                }
            }
        }
    }
}