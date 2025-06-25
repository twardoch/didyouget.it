import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa
import CoreMedia

// Helper functions to make code cleaner
extension AVMutableMetadataItem {
    func setKeySpace(_ keySpace: AVMetadataKeySpace) -> Self {
        self.keySpace = keySpace
        return self
    }
    
    func setKey(_ key: NSCopying & NSObjectProtocol) -> Self {
        self.key = key
        return self
    }
    
    func setValue(_ value: NSCopying & NSObjectProtocol) -> Self {
        self.value = value
        return self
    }
}

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
        #if DEBUG
        print("VideoProcessor initialized")
        #endif
    }
    
    func setupVideoWriter(url: URL, width: Int, height: Int, frameRate: Int, videoQuality: PreferencesManager.VideoQuality) throws -> AVAssetWriter {
        #if DEBUG
        print("Creating video asset writer with output URL: \(url.path)")
        #endif
        do {
            // First check if the file already exists and remove it to avoid conflicts
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                print("Removed existing video file at \(url.path)")
                #endif
            }
            
            // Create an empty placeholder file to test permissions
            do {
                let data = Data()
                try data.write(to: url)
                #if DEBUG
                print("✓ Successfully created empty placeholder file at \(url.path)")
                #endif
                
                // Remove the placeholder since AVAssetWriter will create the actual file
                try FileManager.default.removeItem(at: url)
            } catch {
                print("CRITICAL ERROR: Cannot write to video output path: \(error)")
                throw NSError(domain: "VideoProcessor", code: 1030, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create test file at output path: \(error.localizedDescription)"])
            }
            
            // Now create the AVAssetWriter - ensure proper file type and settings
            videoAssetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
            videoOutputURL = url
            
            // try "placeholder".data(using: .utf8)?.write(to: url) // Commented out this potentially problematic line
            // print("✓ Created placeholder file for video writer") // Also comment out its corresponding print
            
            // Verify the writer was created successfully
            guard let writer = videoAssetWriter else {
                throw NSError(domain: "VideoProcessor", code: 1021, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create video asset writer - writer is nil"])
            }
            
            // Set additional metadata to help with file creation
            let titleItem = AVMutableMetadataItem()
                .setKeySpace(AVMetadataKeySpace.common)
                .setKey(AVMetadataKey.commonKeyTitle as NSString)
                .setValue("DidYouGetIt Recording" as NSString)
                
            let dateItem = AVMutableMetadataItem()
                .setKeySpace(AVMetadataKeySpace.common)
                .setKey(AVMetadataKey.commonKeyCreationDate as NSString)
                .setValue(Date().description as NSString)
                
            writer.metadata = [titleItem, dateItem]
            
            // Check writer status
            if writer.status != .unknown {
                print("WARNING: Video asset writer has unexpected initial status: \(writer.status.rawValue)")
            }
            
            #if DEBUG
            print("✓ Video asset writer created successfully, initial status: \(writer.status.rawValue)")
            #endif
            
            // Verify the file was created by AVAssetWriter
            if FileManager.default.fileExists(atPath: url.path) {
                #if DEBUG
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? UInt64 {
                    print("✓ AVAssetWriter created file on disk: \(url.path) (\(size) bytes)")
                }
                #endif
            } else {
                print("WARNING: AVAssetWriter did not immediately create file on disk")
            }
            
            // Configure video input with settings
            #if DEBUG
            print("Configuring video input settings")
            #endif
            
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
            
            #if DEBUG
            print("Using video quality: \(videoQuality.rawValue) with bitrate: \(bitrate/1_000_000) Mbps")
            #endif
            
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
                    AVVideoAllowFrameReorderingKey: NSNumber(value: false),
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
                ]
            ]
            
            // Log detailed configuration for debugging
            #if DEBUG
            print("VIDEO CONFIG: Width=\(width), Height=\(height), BitRate=\(bitrate/1_000_000)Mbps, FrameRate=\(frameRate)")
            
            print("DEBUG_VP: Attempting to create AVAssetWriterInput...")
            #endif
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            #if DEBUG
            print("DEBUG_VP: AVAssetWriterInput creation attempted (videoInput is \(videoInput == nil ? "nil" : "not nil")).")
            #endif
            guard let videoInput = videoInput else {
                throw NSError(domain: "VideoProcessor", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Failed to create video input"])
            }
            
            videoInput.expectsMediaDataInRealTime = true
            
            #if DEBUG
            print("DEBUG_VP: Checking if writer can add videoInput...")
            #endif
            guard writer.canAdd(videoInput) else {
                #if DEBUG
                print("DEBUG_VP: Writer cannot add videoInput.")
                #endif
                throw NSError(domain: "VideoProcessor", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input to asset writer"])
            }
            #if DEBUG
            print("DEBUG_VP: Writer can add videoInput. Attempting to add...")
            #endif
            
            writer.add(videoInput)
            #if DEBUG
            print("DEBUG_VP: writer.add(videoInput) executed.")
            
            print("DEBUG_VP: Attempting to return from setupVideoWriter...")
            #endif
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
        
        #if DEBUG
        print("Starting video asset writer...")
        #endif
        if videoWriter.status != .unknown {
            print("WARNING: Video writer has unexpected status before starting: \(videoWriter.status.rawValue)")
        }
        
        let didStart = videoWriter.startWriting()
        #if DEBUG
        print("VideoWriter.startWriting() returned \(didStart)")
        #endif
        
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
            #if DEBUG
            print("✓ Video writer started successfully, status: \(videoWriter.status.rawValue)")
            #endif
            return true
        }
    }
    
    func startSession(at time: CMTime) {
        guard let videoWriter = videoAssetWriter else {
            print("ERROR: Video writer is nil when trying to start session")
            return
        }
        
        #if DEBUG
        print("Starting video writer session at time: \(time.seconds)...")
        #endif
        videoWriter.startSession(atSourceTime: time)
        
        // Verify session started correctly
        if videoWriter.status != .writing {
            print("CRITICAL ERROR: Video writer not in writing state after starting session. Status: \(videoWriter.status.rawValue)")
            if let error = videoWriter.error {
                print("CRITICAL ERROR: Video writer error after starting session: \(error.localizedDescription)")
            }
        } else {
            #if DEBUG
            print("✓ Video writer session started successfully")
            #endif
            
            // Immediately force file creation to detect any permission/path issues early
            // This helps ensure the file is properly created on disk
            do {
                let fileManager = FileManager.default
                if !fileManager.fileExists(atPath: videoWriter.outputURL.path) {
                    // Create an empty file to test permissions
                    try Data().write(to: videoWriter.outputURL)
                    #if DEBUG
                    print("✓ Empty video file created for writer initialization")
                    #endif
                } else {
                    #if DEBUG
                    print("✓ Video file already exists at path")
                    #endif
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
        
        // Log more frequently for debugging
        let shouldLogDetail = videoFrameLogCounter == 1 || videoFrameLogCounter % 100 == 0 // Keep this for less frequent debug logs
        
        if shouldLogDetail {
            #if DEBUG
            print("VIDEO FRAME: Processing frame #\(videoFrameLogCounter)")
            #endif
        }
        
        // Before using a potentially less reliable buffer, validate it
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("ERROR: Video sample buffer data is not ready")
            return false
        }
        
        // Get additional buffer info for debugging
        if shouldLogDetail {
            #if DEBUG
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            print("VIDEO FRAME: PTS=\(presentationTimeStamp.seconds)s, Duration=\(duration.seconds)s")
            
            if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
                print("VIDEO FRAME: Dimensions=\(dimensions.width)x\(dimensions.height)")
            }
            #endif
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
        
        // Check writer status and try to recover if possible
        if writer.status != .writing {
            print("WARNING: Writer is not in writing state. Current state: \(writer.status.rawValue)")
            
            // Try to start writing if it's in unknown state
            if writer.status == .unknown {
                #if DEBUG
                print("Attempting to start writer that was in unknown state")
                #endif
                if writer.startWriting() {
                    #if DEBUG
                    print("Successfully started writer from unknown state")
                    #endif
                    writer.startSession(atSourceTime: .zero)
                } else {
                    print("ERROR: Failed to start writer from unknown state")
                    return false
                }
            } else {
                print("ERROR: Writer in unexpected state: \(writer.status.rawValue)")
                return false
            }
        }
        
        // Make sure the input is ready
        if !videoInput.isReadyForMoreMediaData {
            // Wait a moment for input to be ready
            print("WARNING: Video input is not ready for more data, waiting briefly...")
            Thread.sleep(forTimeInterval: 0.01)
            if !videoInput.isReadyForMoreMediaData {
                print("ERROR: Video input still not ready after delay")
                return false
            }
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
        
        // Get the presentation timestamp and ensure it's valid
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Fix for potential zero-duration timestamp issues
        var adjustedBuffer = sampleBuffer
        
        // Adjust timestamp if needed (handling potential negative timestamps or zero duration)
        if presentationTimeStamp.seconds < 0 || CMTimeCompare(presentationTimeStamp, .zero) < 0 || CMTIME_IS_INVALID(presentationTimeStamp) {
            print("WARNING: Adjusting invalid presentation timestamp")
            // Create a modified buffer with adjusted timestamp if needed
            if let adjustedSampleBuffer = adjustSampleBufferTimestamp(sampleBuffer) {
                adjustedBuffer = adjustedSampleBuffer
            } else {
                print("ERROR: Failed to adjust sample buffer timestamp")
                return false
            }
        }
        
        // Force synchronize file periodically to ensure data is written
        if videoFramesProcessed > 0 && videoFramesProcessed % 30 == 0 {
            // Attempt to synchronize file to disk
            if let fileHandle = FileHandle(forWritingAtPath: writer.outputURL.path) {
                fileHandle.synchronizeFile()
                fileHandle.closeFile()
                #if DEBUG
                print("DEBUG: Synchronized file to disk at frame \(videoFramesProcessed)")
                #endif
            }
        }
        
        // Double-check buffer validity
        if !CMSampleBufferIsValid(adjustedBuffer) {
            print("ERROR: Sample buffer is invalid after adjustment")
            return false
        }
        
        // Append the buffer with detailed error checking
        let success = videoInput.append(adjustedBuffer)
        
        if !success {
            print("ERROR: Failed to append video sample buffer")
            
            // Check writer status for detailed diagnostics
            print("CRITICAL: AVAssetWriter status = \(writer.status.rawValue)")
            if let error = writer.error {
                print("CRITICAL: AVAssetWriter error: \(error.localizedDescription)")
                print("CRITICAL: Error details: \(error)")
            }
            
            // Try to create a fallback frame if this is our first frame (critical for file initialization)
            if videoFramesProcessed == 0 {
                #if DEBUG
                print("RECOVERY: Attempting to create fallback frame for first frame")
                #endif
                if createAndAppendFallbackFrame() {
                    #if DEBUG
                    print("✓ RECOVERY: Successfully created fallback first frame")
                    #endif
                    videoFramesProcessed += 1
                    return true
                } else {
                    print("ERROR: Failed to create fallback frame")
                }
            }
            
            return false
        } else {
            // Keep track of processed frames for diagnostics
            videoFramesProcessed += 1
            
            if videoFramesProcessed == 1 {
                #if DEBUG
                print("✓ VIDEO SUCCESS: First frame processed successfully!")
                #endif
                
                // Immediate file size check after first frame
                do {
                    let fileManager = FileManager.default
                    let attributes = try fileManager.attributesOfItem(atPath: writer.outputURL.path)
                    if let fileSize = attributes[.size] as? UInt64 {
                        #if DEBUG
                        print("✓ VIDEO FILE: Size after first frame = \(fileSize) bytes")
                        #endif
                    }
                    
                    // Create a backup file marker to confirm we've started writing frames
                    let markerPath = writer.outputURL.deletingLastPathComponent().appendingPathComponent(".recording_started")
                    try "Started".write(to: markerPath, atomically: true, encoding: .utf8)
                } catch {
                    print("WARNING: Unable to check video file size: \(error.localizedDescription)")
                }
            }
            
            // Log successful append more frequently during development
            if videoFramesProcessed % 30 == 0 { // Keep this frequency for important progress logs
                #if DEBUG
                print("✓ VIDEO SUCCESS: Processed \(videoFramesProcessed) video frames successfully")
                #endif
                
                // Periodically check file size
                do {
                    let fileManager = FileManager.default
                    let attributes = try fileManager.attributesOfItem(atPath: writer.outputURL.path)
                    if let fileSize = attributes[.size] as? UInt64 {
                        #if DEBUG
                        print("✓ VIDEO FILE: Current size = \(fileSize) bytes")
                        #endif
                    }
                } catch {
                    print("WARNING: Unable to check video file size: \(error.localizedDescription)")
                }
            }
            
            return true
        }
    }
    
    // Helper function to create a fallback frame if we can't process the first frame
    private func createAndAppendFallbackFrame() -> Bool {
        guard let videoInput = videoInput else {
            print("ERROR: Video input is nil during fallback frame creation")
            return false
        }
        
        guard let writer = videoAssetWriter, writer.status == .writing else {
            print("ERROR: Writer not in writing state during fallback frame creation")
            return false
        }
        
        // Create a blank frame
        let width = 320
        let height = 240
        let bytesPerRow = width * 4
        
        // Create a black frame
        let bufferSize = height * bytesPerRow
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        memset(buffer, 0, bufferSize)
        
        // Create CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            buffer,
            bytesPerRow,
            nil,
            nil,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            print("ERROR: Failed to create pixel buffer, status: \(status)")
            return false
        }
        
        // Create CMSampleBuffer from pixel buffer
        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30), presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        
        // Create format description
        var formatDescription: CMFormatDescription?
        let formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard formatStatus == noErr, let formatDescription = formatDescription else {
            print("ERROR: Failed to create format description, status: \(formatStatus)")
            return false
        }
        
        // Create sample buffer
        let sampleStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else {
            print("ERROR: Failed to create sample buffer, status: \(sampleStatus)")
            return false
        }
        
        // Append the buffer
        return videoInput.append(sampleBuffer)
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
        let adjustedPTS = self.videoFramesProcessed == 0 ? CMTime.zero : currentTime
        
        #if DEBUG
        // Log the adjustment we're making
        print("TIMESTAMP ADJUST: Original=\(originalPTS.seconds)s, Adjusted=\(adjustedPTS.seconds)s")
        #endif
        
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
        
        #if DEBUG
        print("Finalizing video file...")
        #endif
            
        // Check file size BEFORE finalization
        let fileManager = FileManager.default
        let outputURL = writer.outputURL
        
        if fileManager.fileExists(atPath: outputURL.path) {
            do {
                let attrs = try fileManager.attributesOfItem(atPath: outputURL.path)
                if let fileSize = attrs[FileAttributeKey.size] as? UInt64 {
                    #if DEBUG
                    print("PRE-FINALIZE VIDEO FILE SIZE: \(fileSize) bytes")
                    #endif
                    
                    if fileSize == 0 {
                        print("CRITICAL WARNING: Video file is empty (0 bytes) before finalization!")
                        #if DEBUG
                        // Try to dump detailed writer state for debugging
                        print("WRITER STATE DUMP:")
                        print("  - Status: \(writer.status.rawValue)")
                        print("  - Error: \(writer.error?.localizedDescription ?? "nil")")
                        print("  - Video frames processed: \(self.videoFramesProcessed)")
                        #endif
                    } else {
                        #if DEBUG
                        print("GOOD NEWS: Video file has content before finalization!")
                        #endif
                    }
                }
            } catch {
                print("WARNING: Error checking video file before finalization: \(error)")
            }
        } else {
            print("WARNING: Video file does not exist at path: \(outputURL.path)")
        }
        
        #if DEBUG
        print("Marking video input as finished")
        #endif
        videoInput?.markAsFinished()
        
        // Add a brief delay to ensure processing completes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
        // Finalize the video
        await writer.finishWriting()
        
        var error: Error? = nil
        
        if writer.status == AVAssetWriter.Status.failed {
            error = writer.error
            print("ERROR: Video asset writer failed: \(String(describing: writer.error))")
            return (false, error)
        } else if writer.status == AVAssetWriter.Status.completed {
            #if DEBUG
            print("Video successfully finalized")
            #endif
            
            // Check file size AFTER finalization
            if fileManager.fileExists(atPath: outputURL.path) {
                do {
                    let attrs = try fileManager.attributesOfItem(atPath: outputURL.path)
                    if let fileSize = attrs[FileAttributeKey.size] as? UInt64 {
                        #if DEBUG
                        print("POST-FINALIZE VIDEO FILE SIZE: \(fileSize) bytes")
                        #endif
                        if fileSize == 0 {
                            try? fileManager.removeItem(at: outputURL)
                            print("Removed zero-length video file at \(outputURL.path)")
                        }
                    }
                } catch {
                    print("WARNING: Error checking video file after finalization: \(error)")
                }
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