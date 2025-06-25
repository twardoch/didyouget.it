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
    
    @Published var isStoppingProcessActive: Bool = false
    
    @Published var recordingDuration: TimeInterval = 0
    
    // Create a publisher for timer ticks that SwiftUI views can observe
    let timerPublisher = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @Published var selectedScreen: SCDisplay?
    @Published var recordingArea: CGRect?
    
    private var timer: Timer?
    private var dispatchTimer: DispatchSourceTimer?
    private var startTime: Date?
    
    private var videoOutputURL: URL?
    private var audioOutputURL: URL?
    private var mouseTrackingURL: URL?
    private var keyboardTrackingURL: URL?
    private var recordingFolderURL: URL?
    
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
        #if DEBUG
        print("Initializing RecordingManager")
        #endif
        
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
                    #if DEBUG
                    print("Recording was active when app was closed - attempting to resume")
                    #endif
                    self?.resumePersistedRecording()
                }
            }
        }
    }
    
    private func loadPersistedRecordingState() {
        // Load recording status
        if UserDefaults.standard.bool(forKey: RecordingManager.isRecordingKey) {
            #if DEBUG
            print("Found persisted recording state: recording was active")
            #endif
            
            // Don't set isRecording directly yet, we need to verify and resume first
            // This prevents UI from showing recording is active before we've properly resumed
            
            // Load pause state
            isPaused = UserDefaults.standard.bool(forKey: RecordingManager.isPausedKey)
            
            // Load saved duration if available
            if let savedTime = UserDefaults.standard.object(forKey: RecordingManager.recordingVideoDurationKey) as? TimeInterval {
                recordingDuration = savedTime
                #if DEBUG
                print("Restored recording duration: \(recordingDuration) seconds")
                #endif
            }
            
            // Load video URL
            if let urlString = UserDefaults.standard.string(forKey: RecordingManager.videoOutputURLKey) {
                videoOutputURL = URL(string: urlString)
                #if DEBUG
                print("Restored video output URL: \(urlString)")
                #endif
            }
        } else {
            #if DEBUG
            print("No persisted recording was active")
            #endif
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
        isStoppingProcessActive = false
        
        #if DEBUG
        print("\n=== STARTING RECORDING ===\n")
        #endif
        
        // Check if we have all the required parameters before starting
        switch captureType {
        case .display:
            guard selectedScreen != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No display selected for display recording")
                throw NSError(domain: "RecordingManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: "No display selected. Please select a display to record."])
            }
            #if DEBUG
            print("Recording source: Display with ID \(selectedScreen!.displayID)")
            #endif
            
        case .window:
            guard selectedWindow != nil else {
                isRecording = false // Reset flag if we fail
                print("ERROR: No window selected for window recording")
                throw NSError(domain: "RecordingManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No window selected. Please select a window to record."])
            }
            #if DEBUG
            print("Recording source: Window with ID \(selectedWindow!.windowID) and title '\(selectedWindow!.title ?? "Untitled")'")
            #endif
            
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
            #if DEBUG
            print("Recording source: Area \(Int(recordingArea!.width))×\(Int(recordingArea!.height)) at position (\(Int(recordingArea!.origin.x)), \(Int(recordingArea!.origin.y))) on display \(selectedScreen!.displayID)")
            #endif
        }
        
        // Check preferences and connectivity
        guard let preferences = preferencesManager else {
            isRecording = false // Reset flag if we fail
            print("ERROR: PreferencesManager is not set")
            throw NSError(domain: "RecordingManager", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Internal error: preferences not available."])
        }
        
        #if DEBUG
        print("Recording options: Audio=\(preferences.recordAudio), Mouse=\(preferences.recordMouseMovements), Keyboard=\(preferences.recordKeystrokes)")
        #endif
        
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
            recordingFolderURL = paths.folderURL
            
            // Store the video URL string for persistence
            if let videoURL = videoOutputURL {
                UserDefaults.standard.set(videoURL.absoluteString, forKey: RecordingManager.videoOutputURLKey)
                #if DEBUG
                print("Saved video output URL to UserDefaults: \(videoURL.absoluteString)")
                #endif
            }
            
            // Set recording state to true BEFORE setting up capture session
            // This ensures that any frames that come in during setup will be processed
            isRecording = true
            
            // Configure capture session based on preferences
            // Configure capture session with high-performance settings
            let streamConfig = try captureSessionManager.configureCaptureSession(
                captureType: captureType,
                selectedScreen: selectedScreen,
                selectedWindow: selectedWindow,
                recordingArea: recordingArea,
                frameRate: preferences.frameRate,
                recordAudio: preferences.recordAudio
            )
            
            #if DEBUG
            print("VIDEO CONFIG: Width=\(streamConfig.width), Height=\(streamConfig.height), Quality=\(preferences.videoQuality.rawValue), FrameRate=\(preferences.frameRate)")
            #endif
            
            // CRITICAL: Add a dummy capture callback to ensure proper initialization
            // This ensures the capture system is properly warmed up
            #if DEBUG
            print("Adding dummy capture callback for initialization")
            #endif
            try? await captureSessionManager.addDummyCapture()
            
            // Create content filter based on capture type
            let contentFilter = try captureSessionManager.createContentFilter(
                captureType: captureType,
                selectedScreen: selectedScreen,
                selectedWindow: selectedWindow,
                recordingArea: recordingArea
            )
            
            // Setup video writer
            // Derive the actual frame rate from the streamConfig
            let actualFrameRate = Int(streamConfig.minimumFrameInterval.timescale) / Int(streamConfig.minimumFrameInterval.value)
            #if DEBUG
            print("DEBUG_RM: Actual frame rate from streamConfig for VideoProcessor: \(actualFrameRate) FPS (timescale: \(streamConfig.minimumFrameInterval.timescale), value: \(streamConfig.minimumFrameInterval.value))")
            #endif

            _ = try videoProcessor.setupVideoWriter(
                url: paths.videoURL,
                width: streamConfig.width,
                height: streamConfig.height,
                frameRate: actualFrameRate, // Use actual configured frame rate
                videoQuality: preferences.videoQuality
            )
            #if DEBUG
            print("DEBUG: Returned from videoProcessor.setupVideoWriter successfully.")
            #endif

            // Setup audio writer if needed
            #if DEBUG
            print("DEBUG: Checking audio preferences...")
            #endif
            if preferences.recordAudio {
                #if DEBUG
                print("DEBUG: Audio recording is ENABLED in preferences.")
                #endif
                if preferences.mixAudioWithVideo {
                    #if DEBUG
                    print("DEBUG: Audio mixing with video is ENABLED. Configuring for video writer.")
                    #endif
                    // Configure audio input for video writer
                    _ = audioProcessor.configureAudioInputForVideoWriter(videoWriter: videoProcessor.videoAssetWriter!)
                    #if DEBUG
                    print("DEBUG: audioProcessor.configureAudioInputForVideoWriter called.")
                    #endif
                } else if let audioURL = paths.audioURL {
                    #if DEBUG
                    print("DEBUG: Audio mixing with video is DISABLED. Setting up separate audio writer at URL: \(audioURL.path)")
                    #endif
                    // Create separate audio writer
                    _ = try audioProcessor.setupAudioWriter(url: audioURL)
                    #if DEBUG
                    print("DEBUG: audioProcessor.setupAudioWriter called.")
                    #endif
                } else {
                    #if DEBUG
                    print("DEBUG: Separate audio selected, but audioOutputURL is nil. No separate audio writer will be set up.")
                    #endif
                }
            } else {
                #if DEBUG
                print("DEBUG: Audio recording is DISABLED in preferences.")
                #endif
            }
            #if DEBUG
            print("DEBUG: Finished checking audio preferences.")
            #endif
            
            // Start video and audio writers
            #if DEBUG
            print("Attempting to start video writer...")
            #endif
            if !videoProcessor.startWriting() {
                print("ERROR: videoProcessor.startWriting() returned false.")
                throw NSError(domain: "RecordingManager", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Failed to start video writer"])
            }
            #if DEBUG
            print("✓ Video writer started.")
            #endif
            
            if preferences.recordAudio && !preferences.mixAudioWithVideo {
                #if DEBUG
                print("Attempting to start audio writer...")
                #endif
                if !audioProcessor.startWriting() {
                    print("WARNING: Failed to start audio writer - continuing without audio")
                }
                #if DEBUG
                print("✓ Audio writer started or skipped.")
                #endif
            }
            
            // Create the stream with sample buffer handler
            #if DEBUG
            print("Attempting to create SCStream...")
            #endif
            try captureSessionManager.createStream(
                filter: contentFilter,
                config: streamConfig,
                handler: { [weak self] sampleBuffer, type in
                    guard let self = self else { return }
                    self.handleSampleBuffer(sampleBuffer, type: type)
                }
            )
            #if DEBUG
            print("✓ SCStream created.")
            #endif
            
            // Start the session with time zero
            #if DEBUG
            print("Attempting to start video/audio processor sessions...")
            #endif
            let sessionStartTime = CMTime.zero
            videoProcessor.startSession(at: sessionStartTime)
            
            if preferences.recordAudio && !preferences.mixAudioWithVideo {
                audioProcessor.startSession(at: sessionStartTime)
            }
            #if DEBUG
            print("✓ Video/audio processor sessions started.")
            #endif
            
            // Ensure we're on the main thread for UI updates and timer creation
            #if DEBUG
            print("Attempting to run timer setup on MainActor...")
            #endif
            await MainActor.run {
                #if DEBUG
                print("Inside MainActor.run for timer setup.")
                #endif
                // Record start time after capture starts
                startTime = Date()
                
                // Store start time in UserDefaults for persistence
                UserDefaults.standard.set(startTime!.timeIntervalSince1970, forKey: RecordingManager.recordingStartTimeKey)
                #if DEBUG
                print("Saved recording start time to UserDefaults: \(startTime!)")
                #endif
                
                let startTimeCapture = startTime ?? Date()
                #if DEBUG
                print("Starting recording timer at: \(startTimeCapture)")
                #endif
                
                // Make sure any existing timer is invalidated
                timer?.invalidate()
                
                // Not using the timer start time from capture
                // let timerStartTime = startTimeCapture
                
                // Create a direct update timer with no async complications
                self.startTime = Date() // Ensure startTime is set immediately
                #if DEBUG
                print("Setting immediate startTime to \(self.startTime!)")
                #endif
                
                // Explicitly update UI immediately with zero duration
                self.recordingDuration = 0
                #if DEBUG
                print("Setting initial recordingDuration to 0")
                #endif
                
                // Force UI refresh for immediate effect
                DispatchQueue.main.async {
                    #if DEBUG
                    print("Forcing UI refresh for timer")
                    #endif
                    self.objectWillChange.send()
                }
                
                // Force create a dispatch source timer instead of using Timer
                let timerSource = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                timerSource.schedule(deadline: .now(), repeating: .milliseconds(100))
                
                // Capture startTime in a local constant for the timer handler
                let capturedStartTime = self.startTime!
                #if DEBUG
                print("Creating timer with captured startTime \(capturedStartTime)")
                #endif
                
                // Set the timer event handler
                timerSource.setEventHandler { [weak self] in
                    guard let self = self else { 
                        // This case should ideally not happen if timer is managed properly
                        // print("Timer fired but self is nil")
                        return 
                    }
                    
                    // Only update if we're still recording and not paused
                    guard self.isRecording, !self.isPaused else {
                        // print("Timer fired but recording stopped or paused")
                        return
                    }
                    
                    // Calculate and update duration
                    let newDuration = Date().timeIntervalSince(capturedStartTime)
                    
                    // Set the duration - this is a @Published property so it will update the UI
                    if self.recordingDuration != newDuration {
                        self.recordingDuration = newDuration
                        
                        // Debug output at regular intervals
                        #if DEBUG
                        if Int(newDuration) % 2 == 0 {
                            print("TIMER UPDATE: Recording duration = \(newDuration) seconds")
                        }
                        #endif
                        
                        // Save periodically to UserDefaults
                        if Int(newDuration) % 5 == 0 {
                            UserDefaults.standard.set(newDuration, forKey: RecordingManager.recordingVideoDurationKey)
                            #if DEBUG
                            print("Saved duration \(newDuration) to UserDefaults")
                            #endif
                        }
                    }
                }
                
                // Store and activate the timer
                self.dispatchTimer = timerSource
                timerSource.resume()
                #if DEBUG
                print("✓ Dispatch timer created and activated")
                #endif
                
                // We're not using the old timer anymore, but removing this reference requires more extensive changes
                // self.timer = newTimer
                
                // Not using RunLoop-based timer anymore
                // RunLoop.current.add(newTimer, forMode: .common)
                #if DEBUG
                print("✓ Timer successfully initialized and started")
                #endif
            }
            #if DEBUG
            print("✓ Timer setup block completed.")
            #endif
            
            // Start the capture session
            #if DEBUG
            print("Attempting to start capture session (captureSessionManager.startCapture())...")
            #endif
            try await captureSessionManager.startCapture()
            #if DEBUG
            print("✓ Capture session started.")
            #endif
            
            // Start input tracking if enabled
            #if DEBUG
            print("Attempting to start input tracking...")
            #endif
            startInputTracking()
            #if DEBUG
            print("✓ Input tracking started or skipped.")
            #endif
            
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
        #if DEBUG
        print("DEBUG_RM: handleSampleBuffer called with type: \(type)")
        #endif
        // Skip processing if paused
        if isPaused {
            #if DEBUG
            print("DEBUG_RM: handleSampleBuffer - isPaused is true, returning.")
            #endif
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
        
        #if DEBUG
        // Log accessibility status
        print("Accessibility permission status: \(accessEnabled ? "Granted" : "Denied")")
        #endif
        
        // Check if mouse tracking is enabled
        if preferences.recordMouseMovements, let url = mouseTrackingURL {
            #if DEBUG
            print("Mouse tracking enabled, URL: \(url.path)")
            #endif
            
            if accessEnabled {
                #if DEBUG
                print("Starting mouse tracking")
                #endif
                mouseTracker.startTracking(outputURL: url)
            } else {
                print("WARNING: Mouse tracking requires Accessibility permission - not starting")
            }
        } else {
            #if DEBUG
            print("Mouse tracking disabled or no URL available")
            #endif
        }
        
        // Check if keyboard tracking is enabled
        if preferences.recordKeystrokes, let url = keyboardTrackingURL {
            #if DEBUG
            print("Keyboard tracking enabled, URL: \(url.path)")
            #endif
            
            if accessEnabled {
                #if DEBUG
                print("Starting keyboard tracking")
                #endif
                keyboardTracker.startTracking(outputURL: url, maskSensitive: true)
            } else {
                print("WARNING: Keyboard tracking requires Accessibility permission - not starting")
            }
        } else {
            #if DEBUG
            print("Keyboard tracking disabled or no URL available")
            #endif
        }
    }
    
    @MainActor
    func stopRecording() async {
        #if DEBUG
        print("Stop recording requested via stopRecording()")
        #endif
        
        // Prevent multiple stop operations from running concurrently
        guard !isStoppingProcessActive else {
            #if DEBUG
            print("Stop process already active. Ignoring request.")
            #endif
            return
        }
        isStoppingProcessActive = true
        defer { isStoppingProcessActive = false }

        // Capture the state *before* any changes are made by async operations.
        // However, the primary guard for actual processing will be inside stopRecordingAsyncInternal.

        do {
            // Perform the core stopping logic. 
            try await stopRecordingAsyncInternal()
            #if DEBUG
            print("stopRecordingAsyncInternal completed successfully.")
            #endif
            
        } catch {
            print("Error during stopRecordingAsyncInternal: \(error). Full reset will still be attempted.")
            // We still want to attempt a full reset even if internal stop fails.
        }
        
        // Always ensure a full reset is performed after attempting to stop.
        // This cleans up any residual state and ensures the app is ready for a new recording.
        #if DEBUG
        print("Proceeding to forceFullReset() after stop attempt.")
        #endif
        forceFullReset() 
        
        // UI update is handled by forceFullReset and @Published properties.
        #if DEBUG
        print("stopRecording() finished. UI should reflect stopped state.")
        #endif
    }

    // Renamed from stopRecordingAsync - this is the core logic without the initial guard.
    @MainActor
    private func stopRecordingAsyncInternal() async throws {
        // We no longer guard with isRecording here. 
        // The caller (stopRecording) decides if this logic needs to run.
        // If there was nothing to stop (e.g., no active session), this function should gracefully do nothing or handle it.
        
        // If there's no startTime, it's unlikely a recording was properly started or has data to save.
        guard startTime != nil || videoOutputURL != nil || mouseTrackingURL != nil || keyboardTrackingURL != nil else {
            #if DEBUG
            print("stopRecordingAsyncInternal: No significant recording activity detected (no startTime or output URLs). Skipping extensive cleanup.")
            #endif
            // Still ensure basic state like isRecording is false, but avoid complex operations on nil objects.
            if isRecording {
                #if DEBUG
                print("Setting isRecording = false as a precaution.")
                #endif
                isRecording = false
            }
            if isPaused {
                isPaused = false
            }
            if dispatchTimer != nil || timer != nil {
                dispatchTimer?.cancel()
                dispatchTimer = nil
                timer?.invalidate()
                timer = nil
                #if DEBUG
                print("Timers cancelled.")
                #endif
            }
            recordingDuration = 0
            return
        }

        #if DEBUG
        print("\n=== STOPPING RECORDING (INTERNAL) ===\n")
        #endif
        
        // Set recording state to false. This is crucial.
        if isRecording {
            #if DEBUG
            print("Setting isRecording = false")
            #endif
            isRecording = false
        }
        if isPaused {
            #if DEBUG
            print("Setting isPaused = false")
            #endif
            isPaused = false
        }
        
        // Handle dispatch timer (primary timer)
        if let dispatchTimer = self.dispatchTimer {
            #if DEBUG
            print("Cancelling dispatch timer")
            #endif
            dispatchTimer.cancel()
            self.dispatchTimer = nil // Release the timer object
        } else {
            #if DEBUG
            print("Dispatch timer was already nil.")
            #endif
        }
        
        // Handle regular timer (fallback/older timer, ensure it's also stopped)
        if let timer = self.timer {
            #if DEBUG
            print("Invalidating regular timer")
            #endif
            timer.invalidate()
            self.timer = nil
        }
        
        // Reset duration in UI immediately
        if recordingDuration != 0 {
            #if DEBUG
            print("Explicitly setting recordingDuration to 0 for UI update.")
            #endif
            recordingDuration = 0
        }
        
        // Stop input tracking first
        #if DEBUG
        print("Stopping input tracking")
        #endif
        mouseTracker.stopTracking() // These should be safe to call even if not started
        keyboardTracker.stopTracking()
        
        // Stop capture session
        #if DEBUG
        print("Stopping capture session")
        #endif
        await captureSessionManager.stopCapture() // Should be safe to call
        
        // Add a slight delay to ensure all buffers are flushed before finalizing files.
        // This was identified as helpful in previous debugging.
        #if DEBUG
        print("Waiting for buffers to flush (0.5s delay)...")
        #endif
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Finalize video and audio files
        #if DEBUG
        print("Finalizing recording files")
        #endif
        let (_, videoError) = await videoProcessor.finishWriting() // Should be safe to call
        let (_, audioError) = await audioProcessor.finishWriting() // Should be safe to call
        
        // Verify output files (can be kept as is)
        let currentPreferences = preferencesManager // Capture for consistent check
        OutputFileManager.verifyOutputFiles(
            videoURL: videoOutputURL,
            audioURL: audioOutputURL,
            mouseURL: mouseTrackingURL,
            keyboardURL: keyboardTrackingURL,
            videoFramesProcessed: videoProcessor.getFramesProcessed(),
            audioSamplesProcessed: audioProcessor.getSamplesProcessed(),
            shouldHaveVideo: true, // Assuming video is always primary
            shouldHaveSeparateAudio: currentPreferences?.recordAudio == true && currentPreferences?.mixAudioWithVideo == false,
            shouldHaveMouse: currentPreferences?.recordMouseMovements == true,
            shouldHaveKeyboard: currentPreferences?.recordKeystrokes == true
        )

        // Remove recording directory if no files were produced (or if it's empty)
        if let folder = recordingFolderURL {
            OutputFileManager.cleanupFolderIfEmpty(folder)
            // recordingFolderURL will be nilled by forceFullReset later
        }
        
        #if DEBUG
        print("Recording stopped successfully (Internal)")
        #endif
        
        // Report any errors that occurred during finishWriting
        if let error = videoError ?? audioError {
            print("ERROR: Error during finalization (video or audio): \(error)")
            // Do not re-throw here, allow forceFullReset to run.
            // The error is logged, and the overall stop operation will be in a catch block in the caller.
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
            print("ERROR: Failed to load available content: \(error)")
        }
    }
    
    @MainActor
    func resetRecordingState() async {
        #if DEBUG
        print("Resetting recording state")
        #endif
        
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
        if let folder = recordingFolderURL {
            OutputFileManager.cleanupFolderIfEmpty(folder)
        }
        recordingFolderURL = nil
        
        // Reset start time
        startTime = nil
        
        // Clear persisted recording state
        clearPersistedRecordingState()
        
        #if DEBUG
        print("Recording state reset complete")
        #endif
    }
    
    // Synchronous version of resetRecordingState for UI operations
    // that need immediate state reset without async context
    @MainActor
    func forceFullReset() {
        print("WARNING: Forcing immediate reset of all recording state") // Kept as warning
        
        // Reset all state variables immediately
        isRecording = false
        isPaused = false
        recordingDuration = 0
        
        // Kill all timers
        if let timer = self.timer {
            #if DEBUG
            print("Killing standard timer")
            #endif
            timer.invalidate()
            self.timer = nil
        }
        
        if let dispatchTimer = self.dispatchTimer {
            #if DEBUG
            print("Killing dispatch timer")
            #endif
            dispatchTimer.cancel()
            self.dispatchTimer = nil
        }
        
        // Clear all URLs immediately
        videoOutputURL = nil
        audioOutputURL = nil
        mouseTrackingURL = nil
        keyboardTrackingURL = nil
        recordingFolderURL = nil
        
        // Reset tracking
        startTime = nil
        
        // Clear all persisted state
        UserDefaults.standard.removeObject(forKey: RecordingManager.isRecordingKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.isPausedKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingStartTimeKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.recordingVideoDurationKey)
        UserDefaults.standard.removeObject(forKey: RecordingManager.videoOutputURLKey)
        
        #if DEBUG
        print("Emergency reset complete - all state variables cleared")
        #endif
        
        // Force immediate UI update
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    private func clearPersistedRecordingState() {
        #if DEBUG
        print("Clearing persisted recording state")
        #endif
        
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
        #if DEBUG
        print("PreferencesManager set in RecordingManager: \(manager)")
        #endif
        
        // Store reference in user defaults for emergency recovery
        // This is a backup mechanism for critical app functionality
        UserDefaults.standard.setValue(true, forKey: "preferencesManagerSet")
    }
    
    func getPreferencesManager() -> PreferencesManager? {
        // If preferences manager is nil but should be set, warn about it
        if preferencesManager == nil && UserDefaults.standard.bool(forKey: "preferencesManagerSet") {
            print("WARNING: PreferencesManager is nil but was previously set") // Kept as this is a potential issue indicator
        }
        return preferencesManager
    }
}