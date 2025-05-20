
Good:

- I press Record, the timer starts
- I can pause and resume
- The timer keeps running when I close the UI and reopen it
- I press Stop, the timer stops
- Keyboard and mouse JSON are saved, they seem to be correct

Not good: 

- The video file is zero-length

Conclusion: The actual screen capture or video creation is not working! 

```
Building Did You Get It app in debug mode...
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.24s)
Build successful!
Running application from: /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/.build/x86_64-apple-macosx/debug/DidYouGet
=== APPLICATION INITIALIZATION ===
Application starting up. macOS Version: Version 15.5 (Build 24F74)
Initializing RecordingManager
No persisted recording was active
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
Initializing RecordingManager
No persisted recording was active
WARNING: PreferencesManager not connected to RecordingManager during app init
Initializing RecordingManager
No persisted recording was active
ContentView appeared - ensuring PreferencesManager is connected
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
ContentView onAppear - checking recording state
Not currently recording, safe to reset state
Resetting recording state
Clearing persisted recording state
Recording state reset complete
Record button clicked - first ensuring PreferencesManager is connected
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
PreferencesManager confirmed connected, starting recording
Resetting recording state
Clearing persisted recording state
Recording state reset complete

=== STARTING RECORDING ===

Recording source: Display with ID 69734662
Recording options: Audio=false, Mouse=true, Keyboard=true
Setting up recording state
Setting up capture session
Setting up capture session...
Base output directory: /Users/adam/Movies
Created recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24.mov
Audio recording is disabled
Refreshing available content...
Configuring stream settings...
Setting frame rate to 60 FPS
Aspect ratio preservation enabled (macOS 14+)
Setting up content filter based on capture type: display
Capturing display 69734662 at 3072 x 1920 (with Retina scaling)
Creating SCStream with configured filter and settings
Checking for existing files at destination paths
✓ Directory is writable: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24.mov
✓ Video asset writer created successfully, initial status: 0
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
Starting video asset writer...
✓ Video writer started successfully, status: 1
Starting capture with writers prepared...
SCStreamFrameOutput initialized - ready to receive frames
Screen capture output added successfully
Starting SCStream capture...
SCStream capture started successfully
Starting video writer session at time zero...
✓ Video writer session started successfully at time zero
Saved recording start time to UserDefaults: 2025-05-20 20:44:25 +0000
Starting recording timer at: 2025-05-20 20:44:25 +0000
Starting input tracking
Accessibility permission status: Granted
Mouse tracking enabled, URL: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_mouse.json
Starting mouse tracking
Keyboard tracking enabled, URL: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_keyboard.json
Starting keyboard tracking
Recording started successfully
ContentView onAppear - checking recording state
Recording is active, preserving state

=== STOPPING RECORDING ===

Stopping input tracking
Mouse tracking data saved to: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_mouse.json
Keyboard tracking data saved to: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_keyboard.json
Tearing down capture session

=== STOPPING RECORDING ===

Stopping recording session and processing files...
Video frames processed during session: 0
Audio samples processed during session: 0
Stopping SCStream capture...
Stream capture stopped successfully
Waiting for buffers to flush...
Marking video input as finished
No audio input to mark as finished
Inputs marked as finished, waiting before finalizing files...
Finalizing video file...
PRE-FINALIZE VIDEO FILE SIZE: 0 bytes
CRITICAL WARNING: Video file is empty (0 bytes) before finalization!
WRITER STATE DUMP:
  - Status: 1
  - Error: nil
  - Video frames processed: 0
Video successfully finalized
POST-FINALIZE VIDEO FILE SIZE: 0 bytes
No separate audio asset writer to finalize
Verifying output files...

=== RECORDING DIAGNOSTICS ===

Video frames processed: 0
Audio samples processed: 0
Checking Video file: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24.mov
Video file size: 0 bytes
ERROR: Video file is empty (zero bytes)!
Common causes for empty video files:
1. No valid frames were received from the capture source
2. AVAssetWriter was not properly initialized or started
3. Stream configuration doesn't match the actual content being captured
4. There was an error in the capture/encoding pipeline
Video file created at: 2025-05-20 20:44:24 +0000
Checking Mouse tracking file: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_mouse.json
Mouse tracking file size: 58808 bytes
✓ Mouse tracking file successfully saved with size: 58808 bytes
Mouse tracking file created at: 2025-05-20 20:44:25 +0000
Checking Keyboard tracking file: /Users/adam/Movies/DidYouGetIt_2025-05-20_22-44-24/DidYouGetIt_2025-05-20_22-44-24_keyboard.json
Keyboard tracking file size: 957 bytes
✓ Keyboard tracking file successfully saved with size: 957 bytes
Keyboard tracking file created at: 2025-05-20 20:44:25 +0000
Cleaning up resources...
Recording cleanup complete
Recording stopped successfully
ContentView onAppear - checking recording state
Not currently recording, safe to reset state
Resetting recording state
Clearing persisted recording state
Recording state reset complete
```