import Foundation
@preconcurrency import AVFoundation
@preconcurrency import ScreenCaptureKit
import Cocoa

@available(macOS 12.3, *)
class SCStreamFrameOutput: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer, RecordingManager.SCStreamType) -> Void
    private var screenFrameCount = 0
    private var audioSampleCount = 0
    private var hasReceivedFirstFrame = false
    private var firstFrameTime: CMTime?
    
    init(handler: @escaping (CMSampleBuffer, RecordingManager.SCStreamType) -> Void) {
        self.handler = handler
        super.init()
        #if DEBUG
        print("SCStreamFrameOutput initialized - ready to receive frames")
        #endif
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        #if DEBUG
        // This log can be very verbose, consider enabling only for specific debugging sessions if frame-by-frame detail is needed.
        // For now, reduced frequency logs for screen/audio are below.
        // print("<<<< FRAME RECEIVED BY SCStreamFrameOutput (custom class) - Type: \(type) >>>>")
        #endif
        // Perform basic buffer validation before proceeding
        guard CMSampleBufferIsValid(sampleBuffer) else {
            print("ERROR: Invalid sample buffer received from SCStream - skipping") // Keep as error
            return
        }
        
        switch type {
        case .screen:
            screenFrameCount += 1
            
            // Track the first frame time for potential timing adjustments
            if !hasReceivedFirstFrame {
                firstFrameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                hasReceivedFirstFrame = true
                #if DEBUG
                print("SCStream output: Received FIRST screen frame! PTS=\(firstFrameTime?.seconds ?? 0)s")
                #endif
            }
            
            // Only log occasionally to prevent console flooding
            if screenFrameCount == 1 || screenFrameCount % 300 == 0 { // Keep this frequency for less verbose logs
                #if DEBUG
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received screen frame #\(screenFrameCount), PTS=\(currentPTS.seconds)s")
                #endif
            }
            
            // Forward to handler for processing
            handler(sampleBuffer, .screen)
            
        case .audio:
            audioSampleCount += 1
            // Only log occasionally to prevent console flooding
            if audioSampleCount == 1 || audioSampleCount % 300 == 0 { // Keep this frequency
                #if DEBUG
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received audio sample #\(audioSampleCount), PTS=\(currentPTS.seconds)s")
                #endif
            }
            handler(sampleBuffer, .audio)
            
        case .microphone: // This case might be redundant if .audio handles microphone input from SCStream
            audioSampleCount += 1
            // Only log occasionally to prevent console flooding
            if audioSampleCount == 1 || audioSampleCount % 300 == 0 { // Keep this frequency
                #if DEBUG
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received microphone sample #\(audioSampleCount), PTS=\(currentPTS.seconds)s (via .microphone case)")
                #endif
            }
            handler(sampleBuffer, .audio)
            
        @unknown default:
            print("WARNING: SCStream output: Received unknown type \(type)") // Keep as warning
            break
        }
    }
}