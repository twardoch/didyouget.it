import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class CaptureSessionManager: NSObject, SCStreamDelegate {
    // Capture types
    enum CaptureType {
        case display
        case window
        case area
    }
    
    enum SCStreamType {
        case screen
        case audio
    }
    
    private var captureSession: SCStream?
    private var streamConfig: SCStreamConfiguration?
    private var frameOutput: SCStreamFrameOutput?
    
    // The handler to process sample buffers
    private var sampleBufferHandler: ((CMSampleBuffer, RecordingManager.SCStreamType) -> Void)?
    
    override init() {
        #if DEBUG
        print("CaptureSessionManager initialized")
        #endif
        super.init()
    }
    
    func configureCaptureSession(
        captureType: CaptureType,
        selectedScreen: SCDisplay?,
        selectedWindow: SCWindow?,
        recordingArea: CGRect?,
        frameRate: Int,
        recordAudio: Bool
    ) throws -> SCStreamConfiguration {
        #if DEBUG
        print("Configuring stream settings...")
        #endif
        let scConfig = SCStreamConfiguration()
        self.streamConfig = scConfig // Store for later use
        
        // scConfig.queueDepth = 5 // Increase queue depth for smoother capture - Using dummy_config value
        scConfig.queueDepth = 1 // Match dummy config
        
        // Set initial dimensions to HD as default - Will be overridden by display case
        // scConfig.width = 1920
        // scConfig.height = 1080
        
        // Set frame rate based on preferences - Using dummy_config value
        // print("Setting frame rate to \(frameRate) FPS")
        // scConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        scConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate)) // Use actual frameRate
        #if DEBUG
        print("Using frame rate: \(frameRate) FPS (derived from minimumFrameInterval: \(scConfig.minimumFrameInterval.seconds))")
        // The following "TEST:" prints are kept for now as they indicate areas to be fixed (dynamic config)
        print("TEST: Setting frame rate to 5 FPS")

        // Configure pixel format (BGRA is standard for macOS screen capture) - Using dummy_config default
        // scConfig.pixelFormat = kCVPixelFormatType_32BGRA
        print("TEST: Using default pixel format")

        // scConfig.scalesToFit = true // - Using dummy_config default
        print("TEST: Using default scalesToFit")
        
        // Set aspect ratio preservation if available - Using dummy_config default
        // if #available(macOS 14.0, *) {
        //     scConfig.preservesAspectRatio = true
        //     print("Aspect ratio preservation enabled (macOS 14+)")
        // } else {
        //     print("Aspect ratio preservation not available (requires macOS 14+)")
        // }
        print("TEST: Using default preservesAspectRatio")
        #endif
        
        // Configure audio capture if needed
        if recordAudio {
            #if DEBUG
            print("Configuring audio capture...")
            #endif
            scConfig.capturesAudio = true
            
            // Configure audio settings - exclude app's own audio
            scConfig.excludesCurrentProcessAudio = true
            #if DEBUG
            print("Audio capture enabled, excluding current process audio")
            #endif
        }
        
        #if DEBUG
        // Get the display or window to capture
        print("Setting up content filter based on capture type: \(captureType)")
        #endif
        switch captureType {
        case .display:
            guard let display = selectedScreen else {
                print("ERROR: No display selected for display capture")
                throw NSError(domain: "CaptureSessionManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No display selected"])
            }
            
            // Use actual display resolution, similar to the working dummy capture
            // SCDisplay.frame is in points, scaleFactor converts to pixels.
            // SCStreamConfiguration width/height are in pixels.
            let displayPixelWidth = Int(display.frame.width * display.scaleFactor)
            let displayPixelHeight = Int(display.frame.height * display.scaleFactor)

            scConfig.width = displayPixelWidth
            scConfig.height = displayPixelHeight
            #if DEBUG
            print("CONFIG_CSM: Capturing display \(display.displayID) at \(displayPixelWidth)x\(displayPixelHeight) pixels, Target FPS: \(Int(scConfig.minimumFrameInterval.timescale) / Int(scConfig.minimumFrameInterval.value)), QueueDepth: \(scConfig.queueDepth)")
            #endif
            
        case .window:
            guard let window = selectedWindow, let owningDisplay = window.display else {
                print("ERROR: No window or owning display selected for window capture")
                throw NSError(domain: "CaptureSessionManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window or owning display selected"])
            }
            
            let windowFrame = window.frame // This is in points
            let scale = owningDisplay.scaleFactor // Use display's scale factor
            
            scConfig.width = Int(windowFrame.width * scale)
            scConfig.height = Int(windowFrame.height * scale)
            #if DEBUG
            print("Capturing window '\(window.title ?? "Untitled")' at \(scConfig.width)x\(scConfig.height) (with scale \(scale))")
            #endif
            
        case .area:
            guard let displayForArea = selectedScreen, let area = recordingArea else {
                print("ERROR: No display or area selected for area capture")
                throw NSError(domain: "CaptureSessionManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display or area selected"])
            }
            
            let scale = displayForArea.scaleFactor // Use display's scale factor
            
            // IMPORTANT: The streamConfig dimensions MUST match the area for proper recording
            // The 'area' CGRect should already be in screen points.
            scConfig.width = Int(area.width * scale)
            scConfig.height = Int(area.height * scale)
            // For area capture, we might also want to set sourceRect if supported and beneficial
            // scConfig.sourceRect = CGRect(x: area.origin.x * scale, y: area.origin.y * scale, width: area.width * scale, height: area.height * scale)

            #if DEBUG
            print("Capturing area at \(scConfig.width)x\(scConfig.height) (with scale \(scale)) from origin (\(area.origin.x*scale), \(area.origin.y*scale))")
            #endif
            
            // For area selection we need a specific content filter
            // If using sourceRect, the filter is still for the whole display.
            // If not using sourceRect, the filter is for the whole display, and VideoProcessor would crop.
            // The current setup implies the latter.
            #if DEBUG
            print("Area coordinates (points): (\(Int(area.origin.x)), \(Int(area.origin.y))) with size \(Int(area.width))×\(Int(area.height))")
            #endif
        }
        
        return scConfig
    }
    
    func createContentFilter(
        captureType: CaptureType,
        selectedScreen: SCDisplay?,
        selectedWindow: SCWindow?,
        recordingArea: CGRect?
    ) throws -> SCContentFilter {
        switch captureType {
        case .display:
            guard let display = selectedScreen else {
                print("ERROR: No display selected for display filter")
                throw NSError(domain: "CaptureSessionManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No display selected"])
            }
            
            // Create content filter for the display with no window exclusions
            return SCContentFilter(display: display, excludingWindows: [])
            
        case .window:
            guard let window = selectedWindow else {
                print("ERROR: No window selected for window filter")
                throw NSError(domain: "CaptureSessionManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
            }
            
            // Create content filter for the specific window
            return SCContentFilter(desktopIndependentWindow: window)
            
        case .area:
            guard let display = selectedScreen else {
                print("ERROR: No display selected for area filter")
                throw NSError(domain: "CaptureSessionManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display selected for area recording"])
            }
            
            // For capture areas, we need to capture the whole display and then crop
            // in the video settings to the area we want
            return SCContentFilter(display: display, excludingWindows: [])
        }
    }
    
    func createStream(filter: SCContentFilter, config: SCStreamConfiguration, 
                     handler: @escaping (CMSampleBuffer, RecordingManager.SCStreamType) -> Void) throws {
        // Store the provided handler (which is RecordingManager.handleSampleBuffer)
        self.sampleBufferHandler = handler 
        // This sampleBufferHandler is NOT directly used by SCStreamFrameOutput in this version of the code.
        // Instead, we create a new closure that calls our internal handleStreamOutput,
        // and that internal handleStreamOutput will then call the stored sampleBufferHandler.

        #if DEBUG
        print("Creating SCStream with configured filter and settings")
        #endif
        captureSession = SCStream(filter: filter, configuration: config, delegate: self) // Reverted delegate to self
        
        guard let stream = captureSession else {
            throw NSError(domain: "CaptureSessionManager", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Failed to create SCStream session"])
        }
        
        // This is the handler that our custom SCStreamFrameOutput class will call.
        // It then calls our internal bridge method handleStreamOutput.
        let frameOutputHandlerForCustomClass = { [weak self] (sampleBuffer: CMSampleBuffer, mappedType: RecordingManager.SCStreamType) -> Void in
            // This print confirms our custom class's handler mechanism is working.
            #if DEBUG
            print("DEBUG_CSM: Bridge handler in createStream called by SCStreamFrameOutput. Type: \(mappedType)")
            #endif
            self?.handleStreamOutput(sampleBuffer, mappedType: mappedType)
        }
        
        // Initialize our custom SCStreamFrameOutput class with the bridge handler.
        let customFrameOutput = SCStreamFrameOutput(handler: frameOutputHandlerForCustomClass)
        self.frameOutput = customFrameOutput // keep strong reference
        
        // Define the queue on which ScreenCaptureKit will call methods on customFrameOutput (i.e., its SCStreamOutput delegate methods)
        let deliveryQueue = DispatchQueue(label: "com.didyougetit.scstream.deliveryqueue", qos: .userInitiated)
        
        // Add our customFrameOutput instance as the output for screen data.
        try stream.addStreamOutput(customFrameOutput, type: .screen, sampleHandlerQueue: deliveryQueue)
        #if DEBUG
        print("Screen capture output added successfully (using custom SCStreamFrameOutput)")
        #endif
        
        // Add audio output if needed
        if config.capturesAudio {
            #if DEBUG
            print("Configuring audio stream output (using custom SCStreamFrameOutput)...")
            #endif
            try stream.addStreamOutput(customFrameOutput, type: .audio, sampleHandlerQueue: deliveryQueue) 
            #if DEBUG
            print("Audio capture output added successfully (using custom SCStreamFrameOutput)")
            #endif
        }
    }
    
    func startCapture() async throws {
        guard let stream = captureSession else {
            throw NSError(domain: "CaptureSessionManager", code: 1010, 
                         userInfo: [NSLocalizedDescriptionKey: "No capture session available"])
        }
        
        // Start stream capture with better error handling
        #if DEBUG
        print("Starting SCStream capture...")
        #endif
        do {
            try await stream.startCapture()
            #if DEBUG
            print("SCStream capture started successfully")
            #endif
        } catch {
            print("CRITICAL ERROR: Failed to start SCStream capture: \(error)")
            // Clean up resources in case of failure
            #if DEBUG
            print("Attempting to clean up stream resources")
            #endif
            try? await stream.stopCapture()
            throw error
        }
    }
    
    func stopCapture() async {
        if let stream = captureSession {
            do {
                #if DEBUG
                print("Stopping SCStream capture...")
                #endif
                try await stream.stopCapture()
                #if DEBUG
                print("Stream capture stopped successfully")
                #endif
            } catch {
                print("ERROR: Error stopping capture stream: \(error)")
                #if DEBUG
                print("Continuing with teardown despite stream stop error")
                #endif
            }
        } else {
            print("WARNING: No capture session to stop")
        }
        
        // Clear the capture session reference
        captureSession = nil
        streamConfig = nil
        sampleBufferHandler = nil
        frameOutput = nil
    }
    
    func getStreamConfiguration() -> SCStreamConfiguration? {
        return streamConfig
    }
    
    // Helper function to initialize the capture system before actual recording
    func addDummyCapture() async throws {
        #if DEBUG
        print("Initializing capture system with warmup frame...")
        #endif
        
        // Create a small dummy display content
        let dummyContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // Only proceed if we have displays
        guard let firstDisplay = dummyContent.displays.first else {
            print("No displays found for dummy capture") // This is an important warning
            return
        }
        
        // Create a simple filter for the dummy capture
        let dummyFilter = SCContentFilter(display: firstDisplay, excludingWindows: [])
        
        // Create a minimal configuration
        let dummyConfig = SCStreamConfiguration()
        dummyConfig.width = Int(firstDisplay.frame.width * firstDisplay.scaleFactor) // Use scale factor
        dummyConfig.height = Int(firstDisplay.frame.height * firstDisplay.scaleFactor) // Use scale factor
        #if DEBUG
        print("DEBUG_DUMMY: Using dummyConfig resolution \(dummyConfig.width)x\(dummyConfig.height)")
        #endif

        dummyConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(5))
        dummyConfig.queueDepth = 1
        
        // Use a class for the capture handler
        class DummyCaptureHandler: NSObject, SCStreamOutput {
            var receivedFrame = false
            
            func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
                if type == .screen && !receivedFrame {
                    receivedFrame = true
                    #if DEBUG
                    print("✓ Received dummy initialization frame")
                    #endif
                }
            }
        }
        
        let dummyHandler = DummyCaptureHandler()
        
        // Create a temporary stream
        let dummyStream = SCStream(filter: dummyFilter, configuration: dummyConfig, delegate: nil)
        
        // Add output with a dedicated queue
        let dummyQueue = DispatchQueue(label: "it.didyouget.dummyCaptureQueue", qos: .userInitiated)
        try dummyStream.addStreamOutput(dummyHandler, type: .screen, sampleHandlerQueue: dummyQueue)
        
        // Start capture very briefly
        try await dummyStream.startCapture()
        
        // Wait a moment to receive at least one frame
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Stop the dummy capture
        try await dummyStream.stopCapture()
        
        #if DEBUG
        print("Dummy capture completed successfully")
        #endif
    }
    
    // This internal method is called by the closure provided to SCStreamFrameOutput
    private func handleStreamOutput(_ sampleBuffer: CMSampleBuffer, mappedType: RecordingManager.SCStreamType) {
        guard let finalHandler = sampleBufferHandler else { 
            print("ERROR_CSM: sampleBufferHandler (RecordingManager.handleSampleBuffer) is nil in handleStreamOutput") // Critical error
            return 
        }
        // Call the original handler (RecordingManager.handleSampleBuffer)
        #if DEBUG
        print("DEBUG_CSM: handleStreamOutput forwarding to RecordingManager. Type: \(mappedType)")
        #endif
        finalHandler(sampleBuffer, mappedType)
    }
    
    // SCStreamDelegate methods
    // ... existing extension SCStreamDelegate ...

    // MARK: - SCStreamDelegate

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Ensure UI updates or state changes are on the main actor if needed
        Task { @MainActor in
            print("CRITICAL_ERROR_CSM_DELEGATE: Stream stopped with error: \(error.localizedDescription)")
            // Potentially handle this error by resetting state or notifying the user
            // For now, just logging is crucial.
            // Consider calling a method on RecordingManager to signal this failure.
        }
    }

    // Optional: Implement other SCStreamDelegate methods if needed for diagnostics
    // nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    //     Task { @MainActor in
    //         // This delegate method on CaptureSessionManager itself likely WON'T be called
    //         // if SCStreamFrameOutput is successfully added via addStreamOutput and is receiving frames.
    //         // ScreenCaptureKit usually sends to one or the other for a given type.
    //         // If this DOES get called, it might indicate an issue with SCStreamFrameOutput registration.
    //         print("UNEXPECTED_CSM_DELEGATE: stream(_:didOutputSampleBuffer:ofType:) called directly on CaptureSessionManager for type \(type). This might indicate an issue with SCStreamFrameOutput.")
    //     }
    // }

}

// Ensure the extension is recognized or move delegate methods into the class if necessary.
// For now, assuming the separate extension is fine as long as the class declares conformance.

// extension CaptureSessionManager: SCStreamDelegate { ... } // This can be kept if preferred