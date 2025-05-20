import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import ObjectiveC
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class RecordingManager: ObservableObject {
    // Key constants for UserDefaults
    private static let isRecordingKey = "DidYouGetIt.isRecording"
    private static let isPausedKey = "DidYouGetIt.isPaused"
    private static let recordingStartTimeKey = "DidYouGetIt.recordingStartTime"
    private static let recordingVideoDurationKey = "DidYouGetIt.recordingVideoDuration"
    private static let videoOutputURLKey = "DidYouGetIt.videoOutputURL"
    
    // SCStream types (needed to prevent circular references)
    enum SCStreamType {
        case screen
        case audio
    }
    
    // Published properties with persistence
    @Published var isRecording: Bool = false {
        didSet {
            UserDefaults.standard.set(isRecording, forKey: RecordingManager.isRecordingKey)
        }
    }
    
    @Published var isPaused: Bool = false {
        didSet {
            UserDefaults.standard.set(isPaused, forKey: RecordingManager.isPausedKey)
        }
    }
    
    @Published var recordingDuration: TimeInterval = 0
    @Published var selectedScreen: SCDisplay?
    @Published var recordingArea: CGRect?
    
    private var timer: Timer?
    private var startTime: Date?
    
    private var videoOutputURL: URL?
    private var audioOutputURL: URL?
    private var mouseTrackingURL: URL?
    private var keyboardTrackingURL: URL?
    
    // Input tracking
    private var mouseTracker = MouseTracker()
    private var keyboardTracker = KeyboardTracker()
    
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableWindows: [SCWindow] = []
    @Published var captureType: CaptureSessionManager.CaptureType = .display
    @Published var selectedWindow: SCWindow?
    
    // Component managers for handling specialized tasks
    private var captureSessionManager = CaptureSessionManager()
    private var videoProcessor = VideoProcessor()
    private var audioProcessor = AudioProcessor()
    
    init() {
        print("Initializing RecordingManager")
        
        // Load persisted recording state
        loadPersistedRecordingState()
        
        // Delay permissions check to avoid initialization crashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkPermissions()
            
            // Load content after permissions check
            Task { [weak self] in
                await self?.loadAvailableContent()
                
                // If recording was active when app was closed, try to resume
                if self?.isRecording == true {
                    print("Recording was active when app was closed - attempting to resume")
                    self?.resumePersistedRecording()
                }
            }
        }
    }
    
    private func loadPersistedRecordingState() {
        // Load recording status
        if UserDefaults.standard.bool(forKey: RecordingManager.isRecordingKey) {
            print("Found persisted recording state: recording was active")
            
            // Don't set isRecording directly yet, we need to verify and resume first
            // This prevents UI from showing recording is active before we've properly resumed
            
            // Load pause state
            isPaused = UserDefaults.standard.bool(forKey: RecordingManager.isPausedKey)
            
            // Load saved duration if available
            if let savedTime = UserDefaults.standard.object(forKey: RecordingManager.recordingVideoDurationKey) as? TimeInterval {
                recordingDuration = savedTime
                print("Restored recording duration: \(recordingDuration) seconds")
            }
            
            // Load video URL
            if let urlString = UserDefaults.standard.string(forKey: RecordingManager.videoOutputURLKey) {
                videoOutputURL = URL(string: urlString)
                print("Restored video output URL: \(urlString)")
            }
        } else {
            print("No persisted recording was active")
        }
    }
    
    private func resumePersistedRecording() {
        // In a real implementation, we would try to reconnect to existing recording
        // But since that's complex and likely to fail, we'll just stop any old recording
        
        print("WARNING: Cannot resume previous recording session - resetting state")
        
        // Reset recording state - we can't recover it at this point
        isRecording = false
        isPaused = false
        recordingDuration = 0
        
        // Clear persisted state
        UserDefaults.standard.removeObject(forKey: RecordingManager.isRecordingKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.isPausedKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingStartTimeKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingVideoDurationKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.videoOutputURLKey)
        
        // Show alert about interrupted recording
        showAlert(title: "Recording Interrupted", 
                 message: "The previous recording was interrupted when the application closed. Recording has been stopped.")
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
        
        do {
            // Setup output directory and paths
            let paths = OutputFileManager.createOutputURLs(
                recordAudio: preferences.recordAudio,
                mixAudioWithVideo: preferences.mixAudioWithVideo,
                recordMouseMovements: preferences.recordMouseMovements,
                recordKeystrokes: preferences.recordKeystrokes
            )
            
            videoOutputURL = paths.videoURL
            audioOutputURL = paths.audioURL
            mouseTrackingURL = paths.mouseTrackingURL
            keyboardTrackingURL = paths.keyboardTrackingURL
            
            // Store the video URL string for persistence
            if let videoURL = videoOutputURL {
                UserDefaults.standard.set(videoURL.absoluteString, forKey: RecordingManager.videoOutputURLKey)
                print("Saved video output URL to UserDefaults: \(videoURL.absoluteString)")
            }
            
            // Set recording state to true BEFORE setting up capture session
            // This ensures that any frames that come in during setup will be processed
            isRecording = true
            
            // Configure capture session based on preferences
            let streamConfig = try captureSessionManager.configureCaptureSession(
                captureType: captureType,
                selectedScreen: selectedScreen,
                selectedWindow: selectedWindow,
                recordingArea: recordingArea,
                frameRate: preferences.frameRate,
                recordAudio: preferences.recordAudio
            )
            
            // Create content filter based on capture type
            let contentFilter = try captureSessionManager.createContentFilter(
                captureType: captureType,
                selectedScreen: selectedScreen,
                selectedWindow: selectedWindow,
                recordingArea: recordingArea
            )
            
            // Setup video writer
            _ = try videoProcessor.setupVideoWriter(
                url: paths.videoURL,
                width: streamConfig.width,
                height: streamConfig.height,
                frameRate: preferences.frameRate,
                videoQuality: preferences.videoQuality
            )
            
            // Setup audio writer if needed
            if preferences.recordAudio {
                if preferences.mixAudioWithVideo {
                    // Configure audio input for video writer
                    _ = audioProcessor.configureAudioInputForVideoWriter(videoWriter: videoProcessor.videoAssetWriter!)
                } else if let audioURL = paths.audioURL {
                    // Create separate audio writer
                    _ = try audioProcessor.setupAudioWriter(url: audioURL)
                }
            }
            
            // Start video and audio writers
            if !videoProcessor.startWriting() {
                throw NSError(domain: "RecordingManager", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Failed to start video writer"])
            }
            
            if preferences.recordAudio && !preferences.mixAudioWithVideo {
                if !audioProcessor.startWriting() {
                    print("WARNING: Failed to start audio writer - continuing without audio")
                }
            }
            
            // Create the stream with sample buffer handler
            try captureSessionManager.createStream(
                filter: contentFilter,
                config: streamConfig,
                handler: { [weak self] sampleBuffer, type in
                    guard let self = self else { return }
                    self.handleSampleBuffer(sampleBuffer, type: type)
                }
            )
            
            // Start the session with time zero
            let sessionStartTime = CMTime.zero
            videoProcessor.startSession(at: sessionStartTime)
            
            if preferences.recordAudio && !preferences.mixAudioWithVideo {
                audioProcessor.startSession(at: sessionStartTime)
            }
            
            // Ensure we're on the main thread for UI updates and timer creation
            await MainActor.run {
                // Record start time after capture starts
                startTime = Date()
                
                // Store start time in UserDefaults for persistence
                UserDefaults.standard.set(startTime!.timeIntervalSince1970, forKey: RecordingManager.recordingStartTimeKey)
                print("Saved recording start time to UserDefaults: \(startTime!)")
                
                let startTimeCapture = startTime ?? Date()
                print("Starting recording timer at: \(startTimeCapture)")
                
                // Make sure any existing timer is invalidated
                timer?.invalidate()
                
                // Create a timer that updates the recording duration
                let timerStartTime = startTimeCapture
                
                // Create a timer that will safely dispatch back to the main actor for updates
                let timerStart = timerStartTime // Capture the start time as a local variable
                let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    
                    // Calculate the duration here since it doesn't need actor isolation
                    let duration = Date().timeIntervalSince(timerStart)
                    
                    // Run the UI updates on the MainActor
                    Task { @MainActor in
                        // Only update if we're still recording
                        guard self.isRecording, !self.isPaused else { return }
                        
                        // Update the UI
                        self.recordingDuration = duration
                        
                        // Periodically save duration to UserDefaults (every 5 seconds)
                        if Int(duration) % 5 == 0 {
                            UserDefaults.standard.set(duration, forKey: RecordingManager.recordingVideoDurationKey)
                        }
                    }
                }
                
                // Store the timer reference
                self.timer = newTimer
                
                // Ensure timer doesn't get invalidated by RunLoop modes
                RunLoop.current.add(newTimer, forMode: .common)
                
                print("✓ Timer successfully initialized and started")
            }
            
            // Start the capture session
            try await captureSessionManager.startCapture()
            
            // Start input tracking if enabled
            startInputTracking()
            
            print("Recording started successfully")
        } catch {
            // If we hit any errors, reset the recording state
            print("ERROR: Failed during recording setup: \(error)")
            await resetRecordingState()
            throw error
        }
    }
    
    @MainActor
    private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: SCStreamType) {
        // Skip processing if paused
        if isPaused {
            return
        }
        
        // Process sample buffer based on type
        switch type {
        case .screen:
            _ = videoProcessor.processSampleBuffer(sampleBuffer)
        case .audio:
            if let preferences = preferencesManager {
                _ = audioProcessor.processAudioSampleBuffer(sampleBuffer, isMixingWithVideo: preferences.mixAudioWithVideo)
            }
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
        // Simply forward to the async teardown without altering state first
        // to avoid bypassing the checks in stopRecordingAsync().
        print("Stop recording requested")
        do {
            try await stopRecordingAsync()
        } catch {
            print("Error in stopRecording: \(error)")
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
        
        // Stop capture session
        print("Stopping capture session")
        await captureSessionManager.stopCapture()
        
        // Add a slight delay to ensure all buffers are flushed
        print("Waiting for buffers to flush...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Finalize video and audio files
        print("Finalizing recording files")
        let (_, videoError) = await videoProcessor.finishWriting()
        let (_, audioError) = await audioProcessor.finishWriting()
        
        // Verify output files
        let preferences = preferencesManager
        OutputFileManager.verifyOutputFiles(
            videoURL: videoOutputURL,
            audioURL: audioOutputURL,
            mouseURL: mouseTrackingURL,
            keyboardURL: keyboardTrackingURL,
            videoFramesProcessed: videoProcessor.getFramesProcessed(),
            audioSamplesProcessed: audioProcessor.getSamplesProcessed(),
            shouldHaveVideo: true,
            shouldHaveSeparateAudio: preferences?.recordAudio == true && preferences?.mixAudioWithVideo == false,
            shouldHaveMouse: preferences?.recordMouseMovements == true,
            shouldHaveKeyboard: preferences?.recordKeystrokes == true
        )

        // Remove recording directory if no files were produced
        if let folder = videoOutputURL?.deletingLastPathComponent() {
            OutputFileManager.cleanupFolderIfEmpty(folder)
        }
        
        print("Recording stopped successfully")
        
        // Report any errors that occurred during finishWriting
        if let error = videoError ?? audioError {
            print("ERROR: Error during finalization: \(error)")
            throw error
        }
    }
    
    @MainActor
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        isPaused = true
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    @MainActor
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        isPaused = false
        
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Run the UI updates on the MainActor
            Task { @MainActor in
                // Check if we should continue updating
                guard self.isRecording, !self.isPaused else { return }
                
                // Update the UI if we have a valid start time
                if let startTime = self.startTime {
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
        
        // Store the timer reference 
        self.timer = newTimer
        
        // Ensure timer doesn't get invalidated by RunLoop modes
        RunLoop.current.add(newTimer, forMode: .common)
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
    
    @MainActor
    func resetRecordingState() async {
        print("Resetting recording state")
        
        // Reset recording flags
        isRecording = false
        isPaused = false
        recordingDuration = 0
        
        // Invalidate timers
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
        
        // Reset URLs
        videoOutputURL = nil
        audioOutputURL = nil
        mouseTrackingURL = nil
        keyboardTrackingURL = nil
        
        // Reset start time
        startTime = nil
        
        // Clear persisted recording state
        clearPersistedRecordingState()
        
        print("Recording state reset complete")
    }
    
    private func clearPersistedRecordingState() {
        print("Clearing persisted recording state")
        
        // Clear all recording-related UserDefaults
        UserDefaults.standard.removeObject(forKey: RecordingManager.isRecordingKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.isPausedKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingStartTimeKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingVideoDurationKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.videoOutputURLKey)
    }
    
    // Make preferencesManager internal for access in DidYouGetApp for diagnostics
    var preferencesManager: PreferencesManager?
    
    func setPreferencesManager(_ manager: PreferencesManager) {
        preferencesManager = manager
        print("PreferencesManager set in RecordingManager: \(manager)")
        
        // Store reference in user defaults for emergency recovery
        // This is a backup mechanism for critical app functionality
        UserDefaults.standard.setValue(true, forKey: "preferencesManagerSet")
    }
    
    func getPreferencesManager() -> PreferencesManager? {
        // If preferences manager is nil but should be set, warn about it
        if preferencesManager == nil && UserDefaults.standard.bool(forKey: "preferencesManagerSet") {
            print("WARNING: PreferencesManager is nil but was previously set")
        }
        return preferencesManager
    }
}