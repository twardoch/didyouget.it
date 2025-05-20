
- [x] After clicking Record, the timer does not start running
- [x] Stop button does not change back to Record button after I click Stop
- [x] The app creates empty folders, no files inside
- [x] Previously the app did create the keystrokes JSON and the mouse JSON, but it always created a zero-length MOV file, never a proper video file.

```
Building Did You Get It app in debug mode...
Found unhandled resource at /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/DidYouGet/DidYouGet/Resources
[1/1] Planning build
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.47s)
Build successful!
Running application from: /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/.build/x86_64-apple-macosx/debug/DidYouGet
=== APPLICATION INITIALIZATION ===
Application starting up. macOS Version: Version 15.5 (Build 24F74)
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_00-16-37/DidYouGetIt_2025-05-21_00-16-37.mov
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_00-16-37/DidYouGetIt_2025-05-21_00-16-37.mov
WARNING: PreferencesManager not connected to RecordingManager during app init
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_00-16-37/DidYouGetIt_2025-05-21_00-16-37.mov
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
Created/verified recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04
✓ Successfully tested write permissions in directory
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04.mov
Configuring stream settings...
Setting frame rate to 60 FPS
Aspect ratio preservation enabled (macOS 14+)
Setting up content filter based on capture type: display
Capturing display 69734662 at 3072 x 1920 (with Retina scaling)
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04.mov
✓ Successfully created empty placeholder file at /Users/adam/Movies/DidYouGetIt_2025-05-21_00-17-04/DidYouGetIt_2025-05-21_00-17-04.mov
✓ Video asset writer created successfully, initial status: 0
WARNING: AVAssetWriter did not immediately create file on disk
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
VIDEO CONFIG: Width=3072, Height=1920, BitRate=20Mbps, FrameRate=60
```