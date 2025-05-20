CURRENT ISSUES (as of YYYY-MM-DD HH:MM):

**Primary Issue: Recording does not fully initialize or run.**
Symptoms observed from the last run:
- UI sticks on "Stop" button (meaning `isRecording` becomes true).
- Timer does not tick (stuck at 0:00.0).
- Output JSON files for mouse/keyboard are empty (`[]`).
- Output MOV file is minimal size (e.g., 11 bytes), indicating no video data.

**Diagnosis from logs:**
- `RecordingManager.startRecordingAsync()` sets `isRecording = true` early on.
- However, the function does not seem to complete its execution.
- Specifically, log messages related to timer setup, starting `SCStream`, starting `captureSessionManager.startCapture()`, and input tracking are MISSING.
- The last observed log message from the `startRecordingAsync` sequence is related to video configuration ("VIDEO CONFIG...").
- No explicit error messages (like "ERROR: Failed during recording setup") are printed from the main `catch` block in `startRecordingAsync`.

**Suspicion:**
- A call *after* "VIDEO CONFIG..." log and *before* timer setup (e.g., `videoProcessor.startWriting()`, `captureSessionManager.createStream()`) is either crashing, deadlocking, or throwing an unhandled exception that bypasses the main catch block, or causing a silent exit from the function.

**Next Steps:**
- Added detailed logging within `RecordingManager.startRecordingAsync` to pinpoint the exact line of failure.
- Analyze the new logs after running with this detailed logging.

---
Original issue list (likely all symptoms of the primary issue above):
- When I push Record and I then click Stop, the Record button does not appear, it sticks with "Stop" 
- When I push Record, the timer does not tick, stays at 0
- The final JSONs are just `[]` despite the fact that I've moved the pointer and pressed keys
- The final MOV is 11 bytes
---

```
Building Did You Get It app in debug mode...
Building for debugging...
[11/11] Applying DidYouGet
Build complete! (4.65s)
Build successful!
Running application from: /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/.build/x86_64-apple-macosx/debug/DidYouGet
=== APPLICATION INITIALIZATION ===
Application starting up. macOS Version: Version 15.5 (Build 24F74)
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_01-27-55/DidYouGetIt_2025-05-21_01-27-55.mov
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_01-27-55/DidYouGetIt_2025-05-21_01-27-55.mov
WARNING: PreferencesManager not connected to RecordingManager during app init
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_01-27-55/DidYouGetIt_2025-05-21_01-27-55.mov
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
Base output directory: /Users/adam/Movies
Created/verified recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35
✓ Successfully tested write permissions in directory
Created recording session marker file with session info
Created placeholder for video file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
Created placeholder for mouse tracking file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35_mouse.json
Created placeholder for keyboard tracking file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35_keyboard.json
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
Configuring stream settings...
Setting frame rate to 60 FPS
Aspect ratio preservation enabled (macOS 14+)
Setting up content filter based on capture type: display
Capturing display 69734662 at 3072 x 1920 (with Retina scaling)
Adding dummy capture callback for initialization
Initializing capture system with warmup frame...
✓ Received dummy initialization frame
Dummy capture completed successfully
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
Removed existing video file at /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
✓ Successfully created empty placeholder file at /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov
✓ Created placeholder file for video writer
✓ Video asset writer created successfully, initial status: 0
✓ AVAssetWriter created file on disk: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-29-35/DidYouGetIt_2025-05-21_01-29-35.mov (11 bytes)
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
VIDEO CONFIG: Width=3072, Height=1920, BitRate=20Mbps, FrameRate=60
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
Stop button clicked - requesting stop via RecordingManager
```