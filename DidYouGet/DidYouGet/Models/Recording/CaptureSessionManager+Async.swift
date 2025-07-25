//
//  CaptureSessionManager+Async.swift
//  DidYouGet
//
//  Async/await improvements for CaptureSessionManager
//
// this_file: DidYouGet/DidYouGet/Models/Recording/CaptureSessionManager+Async.swift

import Foundation
import ScreenCaptureKit
import CoreMedia

@available(macOS 12.3, *)
extension CaptureSessionManager {
    
    /// Create stream with async frame processing
    func createStreamAsync(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> AsyncStream<(CMSampleBuffer, RecordingManager.SCStreamType)> {
        
        // Create async output handler
        let asyncOutput = AsyncSCStreamFrameOutput()
        
        // Create the stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        guard let stream = stream else {
            throw NSError(domain: "CaptureSessionManager", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Failed to create stream"])
        }
        
        // Add the async output
        try stream.addStreamOutput(asyncOutput, type: .screen, sampleHandlerQueue: frameHandlerQueue)
        
        if config.capturesAudio {
            try stream.addStreamOutput(asyncOutput, type: .audio, sampleHandlerQueue: frameHandlerQueue)
        }
        
        // Store reference to output
        self.frameOutput = asyncOutput
        
        return asyncOutput.frameStream
    }
    
    /// Process frames using async iteration
    func processFramesAsync(using processor: AsyncFrameProcessor) async throws {
        guard let asyncOutput = frameOutput as? AsyncSCStreamFrameOutput else {
            throw NSError(domain: "CaptureSessionManager", code: 2002, userInfo: [NSLocalizedDescriptionKey: "No async frame output configured"])
        }
        
        // Process frames as they arrive
        for await (sampleBuffer, type) in asyncOutput.frameStream {
            await processor.processFrame(sampleBuffer, type: type)
        }
    }
}

// MARK: - Async Capture Session Protocol

@available(macOS 12.3, *)
protocol AsyncCaptureSession: CaptureSessionProtocol {
    func createStreamAsync(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> AsyncStream<(CMSampleBuffer, RecordingManager.SCStreamType)>
    func processFramesAsync(using processor: AsyncFrameProcessor) async throws
}

// MARK: - Conformance

@available(macOS 12.3, *)
extension CaptureSessionManager: AsyncCaptureSession {}