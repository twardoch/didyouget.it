CURRENT ISSUES (as of YYYY-MM-DD HH:MM):

**Primary Issue: No video frames are being delivered by ScreenCaptureKit.**
Symptoms observed from the last run:
- Recording initialization completes, timer runs, UI is responsive.
- Input tracking (mouse/keyboard JSON) WORKS when Accessibility permissions are granted.
- Output MOV file is 0 bytes because no video frames are processed (`VideoProcessor.videoFramesProcessed` is 0).
- Debug logs show that `SCStreamFrameOutput.stream(_:didOutputSampleBuffer:ofType:)` (our custom class method that should receive frames from SCStream) is NOT being called for `.screen` type.

**Diagnosis from logs:**
- `SCStream.startCapture()` reports success.
- `SCStreamDelegate.stream(_:didStopWithError:)` is NOT called, indicating no explicit stream error.
- The issue seems to be that `SCStream` silently fails to deliver frames after starting.

**Suspicion:**
- A subtle issue with `SCContentFilter` or `SCStreamConfiguration` that doesn't cause an error at setup but prevents frame generation/delivery.
- An underlying `ScreenCaptureKit` or OS-level issue specific to the current environment or display being captured.

**Next Steps:**
- Added a prominent print statement at the absolute beginning of `SCStreamFrameOutput.stream(_:didOutputSampleBuffer:ofType:)`.
- Analyze logs after the next run: if this new print doesn't appear for `.screen` type, it confirms SCStream is not calling our handler.
- If no frames, consider: 
    - Simplifying `SCStreamConfiguration` further (e.g., lower resolution, different pixel format if possible, though BGRA is standard).
    - Trying to capture a different `SCDisplay` if available.
    - Consulting `ScreenCaptureKit` documentation for reasons why a stream might start but not deliver frames.

**Secondary Issue: Input tracking files (JSON) require manual permission.**
- Status: Works correctly IF user grants Accessibility permission in System Settings.
- Action: This is expected behavior. Consider adding in-app guidance or a check that directs the user to System Settings if permission is denied and tracking is enabled.

---
Original issue list (mostly resolved or addressed):
- Record button behavior: FIXED
- Timer not ticking: FIXED
- JSONs empty: Explained by Accessibility (works if granted)
- MOV empty: Current primary issue (no frames delivered)
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