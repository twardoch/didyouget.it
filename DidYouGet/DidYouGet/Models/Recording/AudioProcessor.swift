import Foundation
@preconcurrency import AVFoundation
import Cocoa
import CoreMedia

@available(macOS 12.3, *)
@MainActor
class AudioProcessor {
    private var audioAssetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var audioOutputURL: URL?
    
    // Statistics for diagnostics
    private var audioSamplesProcessed: Int = 0
    private var audioSampleLogCounter: Int = 0
    
    init() {
        #if DEBUG
        print("AudioProcessor initialized")
        #endif
    }
    
    func setupAudioWriter(url: URL) throws -> AVAssetWriter? {
        #if DEBUG
        print("Creating separate audio asset writer with output URL: \(url.path)")
        #endif
        
        // Check if the file already exists and remove it to avoid conflicts
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            #if DEBUG
            print("Removed existing audio file at \(url.path)")
            #endif
        }
        
        do {
            audioAssetWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
            audioOutputURL = url
            
            // Set up audio input with settings
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 44100.0,
                AVEncoderBitRateKey: 128000
            ]
            
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            
            guard let audioInput = audioInput, let writer = audioAssetWriter else {
                print("ERROR: Failed to create audio input or writer")
                return nil
            }
            
            audioInput.expectsMediaDataInRealTime = true
            
            if !writer.canAdd(audioInput) {
                print("ERROR: Cannot add audio input to audio asset writer")
                return nil
            }
            
            writer.add(audioInput)
            #if DEBUG
            print("Audio asset writer created successfully")
            #endif
            
            return writer
        } catch {
            print("ERROR: Failed to create audio asset writer: \(error)")
            throw error
        }
    }
    
    func configureAudioInputForVideoWriter(videoWriter: AVAssetWriter) -> AVAssetWriterInput? {
        // Set up audio input with settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100.0,
            AVEncoderBitRateKey: 128000
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        
        guard let audioInput = audioInput else {
            print("ERROR: Failed to create audio input")
            return nil
        }
        
        audioInput.expectsMediaDataInRealTime = true
        
        if !videoWriter.canAdd(audioInput) {
            print("ERROR: Cannot add audio input to video asset writer")
            return nil
        }
        
        videoWriter.add(audioInput)
        #if DEBUG
        print("Audio input added to video writer successfully")
        #endif
        
        return audioInput
    }
    
    func startWriting() -> Bool {
        guard let audioWriter = audioAssetWriter else {
            // This is a normal scenario if audio is mixed, so not a warning unless in debug.
            #if DEBUG
            print("DEBUG: No separate audio asset writer to start (likely mixed with video or audio disabled).")
            #endif
            return false
        }
        
        #if DEBUG
        print("Starting audio asset writer...")
        #endif
        if audioWriter.status != .unknown {
            print("WARNING: Audio writer has unexpected status before starting: \(audioWriter.status.rawValue)")
        }
        
        _ = audioWriter.startWriting()
        
        // Verify audio writer started successfully
        if audioWriter.status != .writing {
            print("WARNING: Audio writer failed to start writing. Status: \(audioWriter.status.rawValue)")
            if let error = audioWriter.error {
                print("WARNING: Audio writer error: \(error.localizedDescription)")
                return false
            } 
            return false
        } else {
            #if DEBUG
            print("✓ Audio writer started successfully, status: \(audioWriter.status.rawValue)")
            #endif
            return true
        }
    }
    
    func startSession(at time: CMTime) {
        guard let audioWriter = audioAssetWriter else {
             #if DEBUG
            print("DEBUG: No separate audio asset writer for session (likely mixed with video or audio disabled).")
            #endif
            return
        }
        
        #if DEBUG
        print("Starting audio writer session at time: \(time.seconds)...")
        #endif
        audioWriter.startSession(atSourceTime: time)
        
        // Verify audio session started correctly
        if audioWriter.status != .writing {
            print("WARNING: Audio writer not in writing state after starting session. Status: \(audioWriter.status.rawValue)")
            if let error = audioWriter.error {
                print("WARNING: Audio writer error after starting session: \(error.localizedDescription)")
            }
        } else {
            #if DEBUG
            print("✓ Audio writer session started successfully")
            #endif
        }
    }
    
    @MainActor
    func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, isMixingWithVideo: Bool) -> Bool {
        // Debug logging to track frequency of audio samples
        audioSampleLogCounter += 1
        
        // Log only the first sample and then occasionally to avoid flooding console
        let shouldLogDetail = audioSampleLogCounter == 1 || audioSampleLogCounter % 300 == 0 // Keep this frequency
        
        if shouldLogDetail {
            #if DEBUG
            print("AUDIO SAMPLE: Processing sample #\(audioSampleLogCounter)")
            #endif
        }
        
        // Validate the sample buffer
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("ERROR: Audio sample buffer data is not ready")
            return false
        }
        
        // Get additional buffer info for debugging
        if shouldLogDetail {
            #if DEBUG
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let duration = CMSampleBufferGetDuration(sampleBuffer)
            print("AUDIO SAMPLE: PTS=\(presentationTimeStamp.seconds)s, Duration=\(duration.seconds)s")
            
            if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                if let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                    print("AUDIO SAMPLE: Sample Rate=\(audioStreamBasicDescription.pointee.mSampleRate)Hz, Channels=\(audioStreamBasicDescription.pointee.mChannelsPerFrame)")
                }
            }
            #endif
        }
        
        // Access properties directly on the main actor
        guard let audioInput = audioInput else {
            print("ERROR: Audio input is nil")
            return false
        }
        
        guard audioInput.isReadyForMoreMediaData else {
            print("WARNING: Audio input is not ready for more data")
            return false
        }
        
        // Check for discontinuity flags
        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [Any],
           let attachments = attachmentsArray.first as? [String: Any] {
            // Skip samples with discontinuity flag - using string literal "discontinuity"
            if let discontinuity = attachments["discontinuity"] as? Bool, discontinuity {
                print("WARNING: Skipping discontinuous audio sample buffer")
                return false
            }
        }
        
        var success = false
        
        // Check if we're mixing or using separate files
        if isMixingWithVideo || audioAssetWriter == nil {
            // We're mixing with video, so rely on the VideoProcessor to handle this
            success = audioInput.append(sampleBuffer)
            if !success {
                print("ERROR: Failed to append audio sample to mixed video")
            }
        } else {
            // Writing to separate file
            if let writer = audioAssetWriter, writer.status == .writing {
                success = audioInput.append(sampleBuffer)
                if !success {
                    print("ERROR: Failed to append audio sample to separate file")
                    print("AUDIO ERROR: Audio writer status = \(writer.status.rawValue)")
                    if let error = writer.error {
                        print("AUDIO ERROR: Audio writer error: \(error.localizedDescription)")
                    }
                }
            } else {
                print("ERROR: Cannot append audio to separate file - writer not ready")
            }
        }
        
        if success {
            // Track processed samples for diagnostics
            audioSamplesProcessed += 1
            if audioSamplesProcessed % 100 == 0 { // Keep this frequency for important progress logs
                #if DEBUG
                print("✓ AUDIO SUCCESS: Processed \(audioSamplesProcessed) audio samples")
                
                if isMixingWithVideo {
                    print("✓ AUDIO (mixed): Using video writer for audio")
                } else {
                    if let writer = audioAssetWriter, let url = audioOutputURL {
                        print("✓ AUDIO (separate): Status=\(writer.status.rawValue), URL=\(url.path)")
                        
                        // Check file size of separate audio file
                        do {
                            let fileManager = FileManager.default
                            let attributes = try fileManager.attributesOfItem(atPath: url.path)
                            if let fileSize = attributes[.size] as? UInt64 {
                                print("✓ AUDIO FILE: Current size = \(fileSize) bytes")
                            }
                        } catch {
                            print("WARNING: Unable to check audio file size: \(error.localizedDescription)")
                        }
                    }
                }
                #endif
            }
        }
        
        return success
    }
    
    func finishWriting() async -> (Bool, Error?) {
        guard let audioWriter = audioAssetWriter else {
            #if DEBUG
            print("INFO: No separate audio writer to finalize (likely mixed or audio disabled).")
            #endif
            return (true, nil)
        }
        
        #if DEBUG
        print("Finalizing audio file...")
        
        print("Marking audio input as finished")
        #endif
        audioInput?.markAsFinished()
        
        // Add a brief delay to ensure processing completes
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await audioWriter.finishWriting()
        
        if audioWriter.status == .failed {
            let error = audioWriter.error
            print("ERROR: Audio asset writer failed: \(String(describing: error))")
            return (false, error)
        } else if audioWriter.status == .completed {
            #if DEBUG
            print("Audio successfully finalized")
            #endif
            return (true, nil)
        } else {
            print("WARNING: Unexpected audio writer status: \(audioWriter.status.rawValue)")
            return (false, NSError(domain: "AudioProcessor", code: 1041, userInfo: [NSLocalizedDescriptionKey: "Unexpected writer status: \(audioWriter.status.rawValue)"]))
        }
    }
    
    func getSamplesProcessed() -> Int {
        return audioSamplesProcessed
    }
    
    func getOutputURL() -> URL? {
        return audioOutputURL
    }
}