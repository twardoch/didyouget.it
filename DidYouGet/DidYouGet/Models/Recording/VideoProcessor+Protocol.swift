//
//  VideoProcessor+Protocol.swift
//  DidYouGet
//
//  VideoProcessor protocol conformance
//
// this_file: DidYouGet/DidYouGet/Models/Recording/VideoProcessor+Protocol.swift

import Foundation
import AVFoundation
import CoreMedia

// MARK: - VideoProcessing Protocol Conformance

extension VideoProcessor: VideoProcessing {
    
    var isConfigured: Bool {
        videoAssetWriter != nil && videoAssetWriterInput != nil
    }
    
    var encodedFrameCount: Int {
        getFramesProcessed()
    }
    
    func configure(settings: VideoSettings, outputURL: URL) throws {
        // Map VideoSettings to internal configuration
        let quality = settings.quality
        let frameRate = settings.frameRate
        
        // Determine dimensions based on resolution
        let (width, height): (Int, Int)
        switch settings.resolution {
        case .native:
            // Will be determined by actual capture size
            width = 1920  // Default fallback
            height = 1080
        case .fullHD:
            width = 1920
            height = 1080
        case .hd:
            width = 1280
            height = 720
        case .custom(let w, let h):
            width = w
            height = h
        }
        
        // Setup video writer with mapped settings
        _ = try setupVideoWriter(
            url: outputURL,
            width: width,
            height: height,
            frameRate: frameRate,
            videoQuality: quality
        )
    }
    
    func process(pixelBuffer: CVPixelBuffer, timestamp: CMTime) async throws {
        // Convert to CMSampleBuffer for compatibility
        var info = CMSampleTimingInfo()
        info.presentationTimeStamp = timestamp
        info.duration = CMTime.invalid
        info.decodeTimeStamp = CMTime.invalid
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        var sampleBuffer: CMSampleBuffer?
        if let format = formatDescription {
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescription: format,
                sampleTiming: &info,
                sampleBufferOut: &sampleBuffer
            )
        }
        
        if let buffer = sampleBuffer {
            _ = processSampleBuffer(buffer)
        } else {
            throw NSError(domain: "VideoProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create sample buffer"])
        }
    }
    
    func finalize() async throws {
        let (success, error) = await finishWriting()
        if let error = error {
            throw error
        }
        if !success {
            throw NSError(domain: "VideoProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize video"])
        }
    }
}