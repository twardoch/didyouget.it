//
//  SCStreamFrameOutput+Async.swift
//  DidYouGet
//
//  Async/await version of SCStreamFrameOutput
//
// this_file: DidYouGet/DidYouGet/Models/Recording/SCStreamFrameOutput+Async.swift

import Foundation
import ScreenCaptureKit
import CoreMedia

@available(macOS 12.3, *)
class AsyncSCStreamFrameOutput: NSObject, SCStreamOutput {
    
    // AsyncStream for frame delivery
    private var frameContinuation: AsyncStream<(CMSampleBuffer, RecordingManager.SCStreamType)>.Continuation?
    
    // Create async stream for frame processing
    lazy var frameStream: AsyncStream<(CMSampleBuffer, RecordingManager.SCStreamType)> = {
        AsyncStream { continuation in
            self.frameContinuation = continuation
            continuation.onTermination = { _ in
                self.frameContinuation = nil
            }
        }
    }()
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Convert SCStreamOutputType to our internal type
        let internalType: RecordingManager.SCStreamType
        switch type {
        case .screen:
            internalType = .screen
        case .audio:
            internalType = .audio
        @unknown default:
            return // Skip unknown types
        }
        
        // Yield the frame to the async stream
        frameContinuation?.yield((sampleBuffer, internalType))
    }
    
    func terminate() {
        frameContinuation?.finish()
        frameContinuation = nil
    }
}

// MARK: - Async Frame Processor

@available(macOS 12.3, *)
actor AsyncFrameProcessor {
    
    private let videoProcessor: VideoProcessor
    private let audioProcessor: AudioProcessor
    private let preferencesManager: PreferencesManager?
    private var isPaused = false
    
    init(videoProcessor: VideoProcessor, audioProcessor: AudioProcessor, preferencesManager: PreferencesManager?) {
        self.videoProcessor = videoProcessor
        self.audioProcessor = audioProcessor
        self.preferencesManager = preferencesManager
    }
    
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }
    
    func processFrame(_ sampleBuffer: CMSampleBuffer, type: RecordingManager.SCStreamType) async {
        guard !isPaused else { return }
        
        switch type {
        case .screen:
            await processVideoFrame(sampleBuffer)
        case .audio:
            await processAudioFrame(sampleBuffer)
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) async {
        await MainActor.run {
            _ = videoProcessor.processSampleBuffer(sampleBuffer)
        }
    }
    
    private func processAudioFrame(_ sampleBuffer: CMSampleBuffer) async {
        guard let preferences = preferencesManager else { return }
        
        await MainActor.run {
            _ = audioProcessor.processAudioSampleBuffer(
                sampleBuffer,
                isMixingWithVideo: preferences.mixAudioWithVideo
            )
        }
    }
}