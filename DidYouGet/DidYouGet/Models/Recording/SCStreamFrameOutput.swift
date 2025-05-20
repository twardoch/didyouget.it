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
        print("SCStreamFrameOutput initialized - ready to receive frames")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        print("<<<< FRAME RECEIVED BY SCStreamFrameOutput (custom class) - Type: \(type) >>>>")
        // Perform basic buffer validation before proceeding
        guard CMSampleBufferIsValid(sampleBuffer) else {
            print("ERROR: Invalid sample buffer received from SCStream - skipping")
            return
        }
        
        switch type {
        case .screen:
            screenFrameCount += 1
            
            // Track the first frame time for potential timing adjustments
            if !hasReceivedFirstFrame {
                firstFrameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                hasReceivedFirstFrame = true
                print("SCStream output: Received FIRST screen frame! PTS=\(firstFrameTime?.seconds ?? 0)s")
            }
            
            // Only log occasionally to prevent console flooding
            if screenFrameCount == 1 || screenFrameCount % 300 == 0 {
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received screen frame #\(screenFrameCount), PTS=\(currentPTS.seconds)s")
            }
            
            // Forward to handler for processing
            handler(sampleBuffer, .screen)
            
        case .audio:
            audioSampleCount += 1
            // Only log occasionally to prevent console flooding
            if audioSampleCount == 1 || audioSampleCount % 300 == 0 {
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received audio sample #\(audioSampleCount), PTS=\(currentPTS.seconds)s")
            }
            handler(sampleBuffer, .audio)
            
        case .microphone:
            audioSampleCount += 1
            // Only log occasionally to prevent console flooding
            if audioSampleCount == 1 || audioSampleCount % 300 == 0 {
                let currentPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("SCStream output: Received microphone sample #\(audioSampleCount), PTS=\(currentPTS.seconds)s")
            }
            handler(sampleBuffer, .audio)
            
        @unknown default:
            print("SCStream output: Received unknown type \(type)")
            break
        }
    }
}