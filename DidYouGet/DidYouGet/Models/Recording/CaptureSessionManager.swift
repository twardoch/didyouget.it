import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class CaptureSessionManager {
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
    
    // The handler to process sample buffers
    private var sampleBufferHandler: ((CMSampleBuffer, RecordingManager.SCStreamType) -> Void)?
    
    init() {
        print("CaptureSessionManager initialized")
    }
    
    func configureCaptureSession(
        captureType: CaptureType,
        selectedScreen: SCDisplay?,
        selectedWindow: SCWindow?,
        recordingArea: CGRect?,
        frameRate: Int,
        recordAudio: Bool
    ) throws -> SCStreamConfiguration {
        print("Configuring stream settings...")
        let scConfig = SCStreamConfiguration()
        self.streamConfig = scConfig // Store for later use
        
        scConfig.queueDepth = 5 // Increase queue depth for smoother capture
        
        // Set initial dimensions to HD as default
        scConfig.width = 1920
        scConfig.height = 1080
        
        // Set frame rate based on preferences
        print("Setting frame rate to \(frameRate) FPS")
        scConfig.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        
        // Configure pixel format (BGRA is standard for macOS screen capture)
        scConfig.pixelFormat = kCVPixelFormatType_32BGRA
        scConfig.scalesToFit = true
        
        // Set aspect ratio preservation if available
        if #available(macOS 14.0, *) {
            scConfig.preservesAspectRatio = true
            print("Aspect ratio preservation enabled (macOS 14+)")
        } else {
            print("Aspect ratio preservation not available (requires macOS 14+)")
        }
        
        // Configure audio capture if needed
        if recordAudio {
            print("Configuring audio capture...")
            scConfig.capturesAudio = true
            
            // Configure audio settings - exclude app's own audio
            scConfig.excludesCurrentProcessAudio = true
            print("Audio capture enabled, excluding current process audio")
        }
        
        // Get the display or window to capture
        print("Setting up content filter based on capture type: \(captureType)")
        switch captureType {
        case .display:
            guard let display = selectedScreen else {
                print("ERROR: No display selected for display capture")
                throw NSError(domain: "CaptureSessionManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: "No display selected"])
            }
            
            // Update configuration for display resolution with Retina support
            let screenWidth = Int(display.frame.width)
            let screenHeight = Int(display.frame.height)
            let scale = 2 // Retina scale factor
            
            scConfig.width = screenWidth * scale
            scConfig.height = screenHeight * scale
            print("Capturing display \(display.displayID) at \(screenWidth * scale) x \(screenHeight * scale) (with Retina scaling)")
            
        case .window:
            guard let window = selectedWindow else {
                print("ERROR: No window selected for window capture")
                throw NSError(domain: "CaptureSessionManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
            }
            
            let windowWidth = Int(window.frame.width)
            let windowHeight = Int(window.frame.height)
            let scale = 2 // Retina scale factor
            
            scConfig.width = windowWidth * scale
            scConfig.height = windowHeight * scale
            print("Capturing window '\(window.title ?? "Untitled")' at \(windowWidth * scale) x \(windowHeight * scale) (with Retina scaling)")
            
        case .area:
            guard let _ = selectedScreen, let area = recordingArea else {
                print("ERROR: No display or area selected for area capture")
                throw NSError(domain: "CaptureSessionManager", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No display or area selected"])
            }
            
            let areaWidth = Int(area.width)
            let areaHeight = Int(area.height)
            let scale = 2 // Retina scale factor
            
            // IMPORTANT: The streamConfig dimensions MUST match the area for proper recording
            scConfig.width = areaWidth * scale
            scConfig.height = areaHeight * scale
            print("Capturing area at \(areaWidth * scale) x \(areaHeight * scale) (with Retina scaling)")
            
            // For area selection we need a specific content filter
            let rect = CGRect(x: area.origin.x, y: area.origin.y, width: area.width, height: area.height)
            print("Area coordinates: (\(Int(rect.origin.x)), \(Int(rect.origin.y))) with size \(Int(rect.width))×\(Int(rect.height))")
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
        print("Creating SCStream with configured filter and settings")
        self.sampleBufferHandler = handler
        
        captureSession = SCStream(filter: filter, configuration: config, delegate: nil)
        
        guard let stream = captureSession else {
            throw NSError(domain: "CaptureSessionManager", code: 1010, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create capture stream"])
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
        if streamConfig?.capturesAudio == true {
            // Add audio stream output
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioQueue)
            print("Audio capture output added successfully")
        }
    }
    
    func startCapture() async throws {
        guard let stream = captureSession else {
            throw NSError(domain: "CaptureSessionManager", code: 1010, 
                         userInfo: [NSLocalizedDescriptionKey: "No capture session available"])
        }
        
        // Start stream capture with better error handling
        print("Starting SCStream capture...")
        do {
            try await stream.startCapture()
            print("SCStream capture started successfully")
        } catch {
            print("CRITICAL ERROR: Failed to start SCStream capture: \(error)")
            // Clean up resources in case of failure
            print("Attempting to clean up stream resources")
            try? await stream.stopCapture()
            throw error
        }
    }
    
    func stopCapture() async {
        if let stream = captureSession {
            do {
                print("Stopping SCStream capture...")
                try await stream.stopCapture()
                print("Stream capture stopped successfully")
            } catch {
                print("ERROR: Error stopping capture stream: \(error)")
                print("Continuing with teardown despite stream stop error")
            }
        } else {
            print("WARNING: No capture session to stop")
        }
        
        // Clear the capture session reference
        captureSession = nil
        streamConfig = nil
        sampleBufferHandler = nil
    }
    
    func getStreamConfiguration() -> SCStreamConfiguration? {
        return streamConfig
    }
}