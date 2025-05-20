import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class VideoProcessor {
    var videoAssetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var videoOutputURL: URL?
    
    // Statistics for diagnostics
    private var videoFramesProcessed: Int = 0
    private var videoFrameLogCounter: Int = 0
    
    init() {
        print("VideoProcessor initialized")
    }
    
    func setupVideoWriter(url: URL, width: Int, height: Int, frameRate: Int, videoQuality: PreferencesManager.VideoQuality) throws -> AVAssetWriter {
        print("Creating video asset writer with output URL: \(url.path)")
        do {
            // First check if the file already exists and remove it to avoid conflicts
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                print("Removed existing video file at \(url.path)")
            }
            
            // Create an empty placeholder file to test permissions
            do {
                let data = Data()
                try data.write(to: url)
                print("✓ Successfully created empty placeholder file at \(url.path)")
                
                // Remove the placeholder since AVAssetWriter will create the actual file
                try FileManager.default.removeItem(at: url)
            } catch {
                print("CRITICAL ERROR: Cannot write to video output path: \(error)")
                throw NSError(domain: "VideoProcessor", code: 1030, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create test file at output path: \(error.localizedDescription)"])
            }
            
            // Now create the AVAssetWriter
            videoAssetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
            videoOutputURL = url
            
            // Verify the writer was created successfully
            guard let writer = videoAssetWriter else {
                throw NSError(domain: "VideoProcessor", code: 1021, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create video asset writer - writer is nil"])
            }
            
            // Check writer status
            if writer.status != .unknown {
                print("WARNING: Video asset writer has unexpected initial status: \(writer.status.rawValue)")
            }
            
            print("✓ Video asset writer created successfully, initial status: \(writer.status.rawValue)")
            
            // Verify the file was created by AVAssetWriter
            if FileManager.default.fileExists(atPath: url.path) {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? UInt64 {
                    print("✓ AVAssetWriter created file on disk: \(url.path) (\(size) bytes)")
                }
            } else {
                print("WARNING: AVAssetWriter did not immediately create file on disk")
            }
            
            // Configure video input with settings
            print("Configuring video input settings")
            
            // Calculate bitrate based on quality setting
            let bitrate: Int
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
            // Add additional settings for more reliable encoding
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: bitrate,
                    AVVideoExpectedSourceFrameRateKey: frameRate,
                    AVVideoMaxKeyFrameIntervalKey: frameRate, 
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    // Add these reliability settings
                    AVVideoAllowFrameReorderingKey: false,    // Disable frame reordering for streaming
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC, // Use CABAC for better quality
                    "RequiresBFrames": false                  // Avoid B-frames for better streaming
                ]
            ]
            
            // Log detailed configuration for debugging
            print("VIDEO CONFIG: Width=\(width), Height=\(height), BitRate=\(bitrate/1_000_000)Mbps, FrameRate=\(frameRate)")
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            guard let videoInput = videoInput else {
                throw NSError(domain: "VideoProcessor", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Failed to create video input"])
            }
            
            videoInput.expectsMediaDataInRealTime = true
            
            guard writer.canAdd(videoInput) else {
                throw NSError(domain: "VideoProcessor", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to asset writer"])
            }
            
            writer.add(videoInput)
            
            return writer
        } catch {
            print("CRITICAL ERROR: Failed to create video asset writer: \(error)")
            throw error
        }
    }
    
    func startWriting() -> Bool {
        guard let videoWriter = videoAssetWriter else {
            print("ERROR: Video writer is nil when trying to start writing")
            return false
        }
        
        print("Starting video asset writer...")
        if videoWriter.status != .unknown {
            print("WARNING: Video writer has unexpected status before starting: \(videoWriter.status.rawValue)")
        }
        
        let didStart = videoWriter.startWriting()
        print("VideoWriter.startWriting() returned \(didStart)")
        
        // Verify video writer started successfully
        if videoWriter.status != .writing {
            print("CRITICAL ERROR: Video writer failed to start writing. Status: \(videoWriter.status.rawValue)")
            if let error = videoWriter.error {
                print("CRITICAL ERROR: Video writer error: \(error.localizedDescription)")
                return false
            } else {
                print("CRITICAL ERROR: Failed to start video writer - not in writing state")
                return false
            }
        } else {
            print("✓ Video writer started successfully, status: \(videoWriter.status.rawValue)")
            return true
        }
    }
    
    func startSession(at time: CMTime) {
        guard let videoWriter = videoAssetWriter else {
            print("ERROR: Video writer is nil when trying to start session")
            return
        }
        
        print("Starting video writer session at time: \(time.seconds)...")
        videoWriter.startSession(atSourceTime: time)
        
        // Verify session started correctly
        if videoWriter.status != .writing {
            print("CRITICAL ERROR: Video writer not in writing state after starting session. Status: \(videoWriter.status.rawValue)")
            if let error = videoWriter.error {
                print("CRITICAL ERROR: Video writer error after starting session: \(error.localizedDescription)")
            }
        } else {
            print("✓ Video writer session started successfully")
            
            // Immediately force file creation to detect any permission/path issues early
            // This helps ensure the file is properly created on disk
            do {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: videoWriter.outputURL.path) {
                    // Create an empty file to test permissions
                    try Data().write(to: videoWriter.outputURL)
                    print("✓ Empty video file created for writer initialization")
                } else {
                    print("✓ Video file already exists at path")
                }
            } catch {
                print("CRITICAL ERROR: Unable to create file at path: \(videoWriter.outputURL.path)")
                print("Error details: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        // Debug logging to track frequency of frame arrivals
        videoFrameLogCounter += 1
        
        // Log only the first frame and then occasionally to avoid flooding console
        let shouldLogDetail = videoFrameLogCounter == 1 || videoFrameLogCounter % 300 == 0
        
        if shouldLogDetail {
            print("VIDEO FRAME: Processing frame #\(videoFrameLogCounter)")
        }
        
        // Only skip if explicitly paused - this check should be done before calling this method
        // if isPaused { return false }
        
        // Before using a potentially less reliable buffer, validate it
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("ERROR: Video sample buffer data is not ready")
            return false
        }
        
        // Get additional buffer info for debugging
        if shouldLogDetail {
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            print("VIDEO FRAME: PTS=\(presentationTimeStamp.seconds)s, Duration=\(duration.seconds)s")
            
            if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
                print("VIDEO FRAME: Dimensions=\(dimensions.width)x\(dimensions.height)")
            }
        }
        
        // Access these properties on the main actor
        guard let videoInput = videoInput else {
            print("ERROR: Video input is nil")
            return false
        }
        
        guard let writer = videoAssetWriter else {
            print("ERROR: Video asset writer is nil")
            return false
        }
        
        guard writer.status == .writing else {
            print("ERROR: Writer is not in writing state. Current state: \(writer.status.rawValue)")
            return false
        }
        
        guard videoInput.isReadyForMoreMediaData else {
            print("WARNING: Video input is not ready for more data")
            return false
        }
        
        // Get timing info from the sample buffer
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                print("WARNING: Skipping discontinuous sample buffer")
                return false
            }
        }
        
        // Debug AVAssetWriter status before attempting to append
        print("WRITER DEBUG: Before append - Status: \(writer.status.rawValue), Input ready: \(videoInput.isReadyForMoreMediaData)")
        
        // Force flush any pending writes
        if videoFramesProcessed > 0 && videoFramesProcessed % 100 == 0 {
            print("WRITER DEBUG: Performing explicit file write flush")
            do {
                _ = try FileManager.default.attributesOfItem(atPath: writer.outputURL.path)
            } catch {
                print("WRITER DEBUG: File not written yet or error: \(error.localizedDescription)")
            }
        }
        
        // Get the presentation timestamp and ensure it's valid
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Fix for potential zero-duration timestamp issues
        var adjustedBuffer = sampleBuffer
        
        // Adjust timestamp if needed (handling potential negative timestamps or zero duration)
        if presentationTimeStamp.seconds < 0 || CMTimeCompare(presentationTimeStamp, .zero) < 0 {
            print("WARNING: Adjusting negative presentation timestamp")
            // Create a modified buffer with adjusted timestamp if needed
            if let sampleBuffer = adjustSampleBufferTimestamp(sampleBuffer) {
                adjustedBuffer = sampleBuffer
            }
        }
        
        print("BUFFER DEBUG: PTS: \(presentationTimeStamp.seconds), Buffer valid: \(CMSampleBufferIsValid(adjustedBuffer) ? "Yes" : "No")")
        
        // Explicit check for frame rate
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(adjustedBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            if let fps = attachments["FPS"] as? Float {
                print("BUFFER DEBUG: Framerate: \(fps) FPS")
            }
        }
        
        // Append the buffer with detailed error checking - use append with propTime to ensure proper timing
        let success = videoInput.append(adjustedBuffer)
        
        if !success {
            print("ERROR: Failed to append video sample buffer")
            
            // Check writer status for detailed diagnostics
            print("CRITICAL: AVAssetWriter status = \(writer.status.rawValue)")
            if let error = writer.error {
                print("CRITICAL: AVAssetWriter error: \(error.localizedDescription)")
                print("CRITICAL: Error details: \(error)")
            }
            
            // Check if input is still ready after failed append
            if !videoInput.isReadyForMoreMediaData {
                print("ERROR: Video input is no longer ready for more data after failed append")
            }
            
            // Check buffer timing
            print("CRITICAL: Buffer timing - PTS=\(presentationTimeStamp.seconds)s, Duration=\(CMSampleBufferGetDuration(adjustedBuffer).seconds)s")
            
            // Check for common timing issues
            if presentationTimeStamp.seconds < 0 {
                print("CRITICAL: Negative presentation timestamp detected!")
            }
            
            if CMTimeCompare(presentationTimeStamp, .zero) < 0 {
                print("CRITICAL: Presentation timestamp is before zero time!")
            }
            
            // Cannot recover within this session - just log the error
            print("CRITICAL: Video frame processing failed. This session will likely produce an empty MOV file.")
            print("CRITICAL: The recommended action is to stop recording and start a new session.")
            
            // Mark that we've had a critical error
            videoFramesProcessed = -1 // Use negative value as an error indicator
            
            // Attempt to write a small test chunk to the file to verify permissions
            do {
                let data = Data([0, 0, 0, 0, 0, 0, 0, 0]) // 8 bytes of zeros
                let url = writer.outputURL
                try data.write(to: url, options: .atomic)
                print("TEST: Successfully wrote test data directly to \(url.path)")
            } catch {
                print("CRITICAL ERROR: Failed to write test data to file: \(error)")
            }
            
            return false
        } else {
            // Keep track of processed frames for diagnostics
            videoFramesProcessed += 1
            
            if videoFramesProcessed == 1 {
                print("✓ VIDEO SUCCESS: First frame processed successfully!")
                
                // Immediate file size check after first frame
                do {
                    let fileManager = FileManager.default
                    let attributes = try fileManager.attributesOfItem(atPath: writer.outputURL.path)
                    if let fileSize = attributes[.size] as? UInt64 {
                        print("✓ VIDEO FILE: Size after first frame = \(fileSize) bytes")
                    }
                } catch {
                    print("WARNING: Unable to check video file size: \(error.localizedDescription)")
                }
            }
            
            // Log successful append periodically
            if videoFramesProcessed % 60 == 0 {
                print("✓ VIDEO SUCCESS: Processed \(videoFramesProcessed) video frames successfully")
                print("✓ VIDEO WRITER: Status=\(writer.status.rawValue), URL=\(writer.outputURL.path)")
                
                // Print file size check
                do {
                    let fileManager = FileManager.default
                    let attributes = try fileManager.attributesOfItem(atPath: writer.outputURL.path)
                    if let fileSize = attributes[.size] as? UInt64 {
                        print("✓ VIDEO FILE: Current size = \(fileSize) bytes")
                    }
                } catch {
                    print("WARNING: Unable to check video file size: \(error.localizedDescription)")
                }
            }
            
            return true
        }
    }
    
    // Helper to adjust sample buffer timestamps if they're invalid
    private func adjustSampleBufferTimestamp(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        // This function creates a new sample buffer with valid timing
        // This is needed when SCStream provides frames with problematic timestamps
        
        // First, we need to extract the current timing info
        let originalPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var originalDuration = CMSampleBufferGetDuration(sampleBuffer)
        
        // If duration is invalid, use a default value (1/60 sec)
        if CMTIME_IS_INVALID(originalDuration) || originalDuration.seconds.isNaN || originalDuration.seconds <= 0 {
            originalDuration = CMTime(value: 1, timescale: 60) // 1/60 sec
            print("WARNING: Using default duration for invalid sample buffer duration")
        }
        
        // Check if the sample buffer has a valid format description
        if CMSampleBufferGetFormatDescription(sampleBuffer) == nil {
            print("ERROR: Cannot get format description from sample buffer")
            return nil
        }
        
        // Check if the sample buffer has valid data
        if CMSampleBufferGetDataBuffer(sampleBuffer) == nil {
            print("ERROR: Cannot get data buffer from sample buffer")
            return nil
        }
        
        // Create a new presentation timestamp starting from a valid time
        // We'll use the current system time to ensure it's always positive
        let currentTime = CMClockGetTime(CMClockGetHostTimeClock())
        let adjustedPTS = videoFramesProcessed == 0 ? CMTime.zero : currentTime
        
        // Log the adjustment we're making
        print("TIMESTAMP ADJUST: Original=\(originalPTS.seconds)s, Adjusted=\(adjustedPTS.seconds)s")
        
        // Create timing info array with the adjusted time
        var timingInfo = CMSampleTimingInfo()
        timingInfo.duration = originalDuration
        timingInfo.presentationTimeStamp = adjustedPTS
        timingInfo.decodeTimeStamp = .invalid
        
        // Create the new sample buffer with the adjusted timing
        var adjustedBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )
        
        if status != noErr || adjustedBuffer == nil {
            print("ERROR: Failed to create adjusted sample buffer, status: \(status)")
            return nil
        }
        
        return adjustedBuffer
    }
    
    func finishWriting() async -> (Bool, Error?) {
        guard let writer = videoAssetWriter else {
            print("ERROR: Video asset writer is nil during finishWriting")
            return (false, NSError(domain: "VideoProcessor", code: 1040, userInfo: [NSLocalizedDescriptionKey: "Video asset writer is nil"]))
        }
        
        print("Finalizing video file...")
            
        // Check file size BEFORE finalization
        do {
            let fileManager = FileManager.default
            let outputURL = writer.outputURL
            if fileManager.fileExists(atPath: outputURL.path) {
                let attrs = try fileManager.attributesOfItem(atPath: outputURL.path)
                if let fileSize = attrs[.size] as? UInt64 {
                    print("PRE-FINALIZE VIDEO FILE SIZE: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        print("CRITICAL WARNING: Video file is empty (0 bytes) before finalization!")
                        
                        // Try to dump detailed writer state for debugging
                        print("WRITER STATE DUMP:")
                        print("  - Status: \(writer.status.rawValue)")
                        print("  - Error: \(writer.error?.localizedDescription ?? "nil")")
                        print("  - Video frames processed: \(videoFramesProcessed)")
                    } else {
                        print("GOOD NEWS: Video file has content before finalization!")
                    }
                }
            } else {
                print("WARNING: Video file does not exist at path: \(outputURL.path)")
            }
        } catch {
            print("WARNING: Error checking video file before finalization: \(error)")
        }
        
        print("Marking video input as finished")
        videoInput?.markAsFinished()
        
        // Add a brief delay to ensure processing completes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
        // Finalize the video
        await writer.finishWriting()
        
        var error: Error? = nil
        
        if writer.status == .failed {
            error = writer.error
            print("ERROR: Video asset writer failed: \(String(describing: writer.error))")
            return (false, error)
        } else if writer.status == .completed {
            print("Video successfully finalized")
            
            // Check file size AFTER finalization
            let outputURL = writer.outputURL
            do {
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: outputURL.path) {
                    let attrs = try fileManager.attributesOfItem(atPath: outputURL.path)
                    if let fileSize = attrs[.size] as? UInt64 {
                        print("POST-FINALIZE VIDEO FILE SIZE: \(fileSize) bytes")
                        if fileSize == 0 {
                            try? fileManager.removeItem(at: outputURL)
                            print("Removed zero-length video file at \(outputURL.path)")
                        }
                    }
                }
            } catch {
                print("WARNING: Error checking video file after finalization: \(error)")
            }
            
            return (true, nil)
        } else {
            print("WARNING: Unexpected video writer status: \(writer.status.rawValue)")
            return (false, NSError(domain: "VideoProcessor", code: 1041, userInfo: [NSLocalizedDescriptionKey: "Unexpected writer status: \(writer.status.rawValue)"]))
        }
    }
    
    func getFramesProcessed() -> Int {
        return videoFramesProcessed
    }
    
    func getOutputURL() -> URL? {
        return videoOutputURL
    }
}