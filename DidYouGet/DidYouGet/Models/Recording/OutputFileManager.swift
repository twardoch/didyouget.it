import Foundation

@available(macOS 12.3, *)
class OutputFileManager {
    
    struct RecordingPaths {
        let baseDirectory: URL
        let folderURL: URL
        let videoURL: URL
        let audioURL: URL?
        let mouseTrackingURL: URL?
        let keyboardTrackingURL: URL?
    }
    
    static func createOutputURLs(recordAudio: Bool, mixAudioWithVideo: Bool, 
                                 recordMouseMovements: Bool, recordKeystrokes: Bool) -> RecordingPaths {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let baseName = "DidYouGetIt_\(timestamp)"
        let videoFileName = "\(baseName).mov" // Will be changed to .mp4 in a later step
        let audioFileName = "\(baseName)_audio.m4a"
        
        let documentsPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        #if DEBUG
        print("Base output directory: \(documentsPath.path)")
        #endif
        
        // Create folder for this recording session
        let folderURL = documentsPath.appendingPathComponent(baseName, isDirectory: true)
        
        // Verify if the directory exists already from a previous attempt
        if FileManager.default.fileExists(atPath: folderURL.path) {
            #if DEBUG
            print("Recording directory already exists at: \(folderURL.path)")
            #endif
            // Try to clean up any existing files - they might be empty/corrupt from previous attempts
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                for item in contents {
                    try FileManager.default.removeItem(at: item)
                    #if DEBUG
                    print("Cleaned up existing file: \(item.path)")
                    #endif
                }
            } catch {
                print("WARNING: Failed to clean up existing directory: \(error)")
            }
        }
        
        // Now create or ensure the directory exists
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            #if DEBUG
            print("Created/verified recording directory: \(folderURL.path)")
            #endif
            
            // Write a small test file to verify permissions
            let testFile = folderURL.appendingPathComponent(".write_test")
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            #if DEBUG
            print("✓ Successfully tested write permissions in directory")
            #endif
            
            // CRITICAL FIX: Create a session marker file that will exist even if recording fails
            // This ensures we have at least one file in the directory
            let sessionMarkerFile = folderURL.appendingPathComponent(".recording_session_marker")
            let sessionInfo = """
            Recording started: \(Date())
            Base name: \(baseName)
            Audio: \(recordAudio)
            Audio mixed with video: \(mixAudioWithVideo)
            Mouse movements: \(recordMouseMovements)
            Keystrokes: \(recordKeystrokes)
            """
            try sessionInfo.write(to: sessionMarkerFile, atomically: true, encoding: .utf8)
            #if DEBUG
            print("Created recording session marker file with session info")
            #endif
            
            // CRITICAL FIX: Create 0-byte placeholders for all output files to ensure they exist
            // This prevents empty directories even if recording fails
            
            // Create video placeholder
            let videoFileURL = folderURL.appendingPathComponent(videoFileName)
            if !FileManager.default.fileExists(atPath: videoFileURL.path) {
                FileManager.default.createFile(atPath: videoFileURL.path, contents: Data())
                #if DEBUG
                print("Created placeholder for video file at: \(videoFileURL.path)")
                #endif
            }
            
            // Create audio placeholder if needed
            if recordAudio && !mixAudioWithVideo {
                let audioFileURL = folderURL.appendingPathComponent(audioFileName)
                if !FileManager.default.fileExists(atPath: audioFileURL.path) {
                    FileManager.default.createFile(atPath: audioFileURL.path, contents: Data())
                    #if DEBUG
                    print("Created placeholder for audio file at: \(audioFileURL.path)")
                    #endif
                }
            }
            
            // Create mouse tracking placeholder if needed
            if recordMouseMovements {
                let mouseFileURL = folderURL.appendingPathComponent("\(baseName)_mouse.json")
                if !FileManager.default.fileExists(atPath: mouseFileURL.path) {
                    // Create with empty JSON array to ensure it's valid JSON even if recording fails
                    try "[]".write(to: mouseFileURL, atomically: true, encoding: .utf8)
                    #if DEBUG
                    print("Created placeholder for mouse tracking file at: \(mouseFileURL.path)")
                    #endif
                }
            }
            
            // Create keyboard tracking placeholder if needed
            if recordKeystrokes {
                let keyboardFileURL = folderURL.appendingPathComponent("\(baseName)_keyboard.json")
                if !FileManager.default.fileExists(atPath: keyboardFileURL.path) {
                    // Create with empty JSON array to ensure it's valid JSON even if recording fails
                    try "[]".write(to: keyboardFileURL, atomically: true, encoding: .utf8)
                    #if DEBUG
                    print("Created placeholder for keyboard tracking file at: \(keyboardFileURL.path)")
                    #endif
                }
            }
        } catch {
            print("CRITICAL ERROR: Failed to create/access recording directory: \(error)")
        }
        
        // Create URLs for tracking data
        let mouseTrackingPath = recordMouseMovements ? 
            folderURL.appendingPathComponent("\(baseName)_mouse.json") : nil
        let keyboardTrackingPath = recordKeystrokes ? 
            folderURL.appendingPathComponent("\(baseName)_keyboard.json") : nil
        
        #if DEBUG
        if let mouseTrackingPath = mouseTrackingPath {
            print("Mouse tracking path: \(mouseTrackingPath.path)")
        }
        
        if let keyboardTrackingPath = keyboardTrackingPath {
            print("Keyboard tracking path: \(keyboardTrackingPath.path)")
        }
        #endif
        
        // Create video and optional audio URLs
        let videoURL = folderURL.appendingPathComponent(videoFileName)
        #if DEBUG
        print("Video output path: \(videoURL.path)")
        #endif
        
        let audioURL: URL?
        if recordAudio && !mixAudioWithVideo {
            audioURL = folderURL.appendingPathComponent(audioFileName)
            #if DEBUG
            print("Separate audio output path: \(audioURL?.path ?? "nil")")
            #endif
        } else {
            audioURL = nil
            #if DEBUG
            print("No separate audio file will be created (mixed with video or audio disabled)")
            #endif
        }
        
        return RecordingPaths(
            baseDirectory: documentsPath,
            folderURL: folderURL,
            videoURL: videoURL,
            audioURL: audioURL,
            mouseTrackingURL: mouseTrackingPath,
            keyboardTrackingURL: keyboardTrackingPath
        )
    }
    
    static func verifyOutputFiles(videoURL: URL?, audioURL: URL?, mouseURL: URL?, keyboardURL: URL?,
                                 videoFramesProcessed: Int, audioSamplesProcessed: Int,
                                 shouldHaveVideo: Bool, shouldHaveSeparateAudio: Bool,
                                 shouldHaveMouse: Bool, shouldHaveKeyboard: Bool) {
        #if DEBUG
        print("\n=== RECORDING DIAGNOSTICS ===\n")
        print("Video frames processed: \(videoFramesProcessed)")
        print("Audio samples processed: \(audioSamplesProcessed)")
        #endif
        
        // Helper function to check file size and validity
        func checkFileStatus(url: URL?, fileType: String, expectedNonEmpty: Bool) {
            guard let url = url else {
                if expectedNonEmpty {
                    print("ERROR: \(fileType) URL is nil but was expected to be present")
                }
                return
            }
            
            #if DEBUG
            print("Checking \(fileType) file: \(url.path)")
            #endif
            
            if FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attrs[.size] as? UInt64 {
                        #if DEBUG
                        print("\(fileType) file size: \(fileSize) bytes")
                        #endif
                        
                        if fileSize == 0 {
                            print("ERROR: \(fileType) file is empty (zero bytes)!")
                            #if DEBUG
                            if fileType == "Video" {
                                print("Common causes for empty video files:")
                                print("1. No valid frames were received from the capture source")
                                print("2. AVAssetWriter was not properly initialized or started")
                                print("3. Stream configuration doesn't match the actual content being captured")
                                print("4. There was an error in the capture/encoding pipeline")
                            }
                            #endif
                        } else if fileSize < 1000 && (fileType == "Video" || fileType == "Audio") {
                            print("WARNING: \(fileType) file is suspiciously small (\(fileSize) bytes)")
                        } else {
                            #if DEBUG
                            print("✓ \(fileType) file successfully saved with size: \(fileSize) bytes")
                            #endif
                        }
                    } else {
                        print("WARNING: Unable to read \(fileType) file size attribute")
                    }
                    
                    #if DEBUG
                    // Print creation date for debugging
                    if let creationDate = attrs[.creationDate] as? Date {
                        print("\(fileType) file created at: \(creationDate)")
                    }
                    #endif
                } catch {
                    print("ERROR: Failed to get \(fileType) file attributes: \(error)")
                }
            } else {
                if expectedNonEmpty {
                    print("ERROR: \(fileType) file not found at expected location: \(url.path)")
                } else {
                    #if DEBUG
                    print("\(fileType) file not created (not expected for this configuration)")
                    #endif
                }
            }
        }
        
        // Check all output files
        checkFileStatus(url: videoURL, fileType: "Video", expectedNonEmpty: shouldHaveVideo)
        checkFileStatus(url: audioURL, fileType: "Audio", expectedNonEmpty: shouldHaveSeparateAudio)
        checkFileStatus(url: mouseURL, fileType: "Mouse tracking", expectedNonEmpty: shouldHaveMouse)
        checkFileStatus(url: keyboardURL, fileType: "Keyboard tracking", expectedNonEmpty: shouldHaveKeyboard)
        
        // If the video file is empty but we processed frames, something went wrong
        if videoFramesProcessed > 0 {
            if let url = videoURL, FileManager.default.fileExists(atPath: url.path) {
                if let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64, fileSize == 0 {
                    print("\nCRITICAL ERROR: Processed \(videoFramesProcessed) frames but video file is empty!")
                    print("This indicates a serious issue with the AVAssetWriter configuration or initialization.")
                }
            }
        }
    }

    /// Remove the recording folder if it contains no visible files.
    static func cleanupFolderIfEmpty(_ folderURL: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folderURL,
                                                                      includingPropertiesForKeys: [.isRegularFileKey],
                                                                      options: [.skipsHiddenFiles])
            let regularFiles = contents.filter { url in
                (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }

            if regularFiles.isEmpty {
                try FileManager.default.removeItem(at: folderURL)
                #if DEBUG
                print("Removed empty recording directory: \(folderURL.path)")
                #endif
            }
        } catch {
            print("WARNING: Failed to clean up folder \(folderURL.path): \(error)")
        }
    }
}