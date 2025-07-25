//
//  AudioProcessor+Protocol.swift
//  DidYouGet
//
//  AudioProcessor protocol conformance
//
// this_file: DidYouGet/DidYouGet/Models/Recording/AudioProcessor+Protocol.swift

import Foundation
import AVFoundation

// MARK: - AudioProcessing Protocol Conformance

extension AudioProcessor: AudioProcessing {
    
    var isConfigured: Bool {
        audioAssetWriter != nil || audioAssetWriterInput != nil
    }
    
    var isProcessing: Bool {
        isWriting
    }
    
    func configureAudio(device: AVCaptureDevice?, settings: AudioSettings) throws {
        // For now, we'll use the existing setup methods
        // In the future, this could be expanded to support device selection
        
        // Create a temporary URL for audio if not mixing with video
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio.m4a")
        _ = try setupAudioWriter(url: tempURL)
    }
    
    func startProcessing() async throws {
        guard audioAssetWriter != nil else {
            throw NSError(domain: "AudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio writer not configured"])
        }
        
        if !startWriting() {
            throw NSError(domain: "AudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start audio processing"])
        }
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) async throws {
        // Convert AVAudioPCMBuffer to CMSampleBuffer
        // This is a simplified implementation - in production, proper conversion would be needed
        
        // For now, throw not implemented
        throw NSError(domain: "AudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAudioPCMBuffer processing not implemented"])
    }
    
    func stopProcessing() async throws {
        // Stop is handled by finalize
        await finalize()
    }
    
    func finalize() async throws {
        let (success, error) = await finishWriting()
        if let error = error {
            throw error
        }
        if !success {
            throw NSError(domain: "AudioProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize audio"])
        }
    }
}