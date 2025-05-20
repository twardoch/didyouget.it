
On first launch: 

- I click Record but timer does not start running
- I click Stop but the button does not change back into the Record button
- I quit the app
- Empty folder DidYouGetIt_2025-05-20_23-14-21 without files

```
Building Did You Get It app in debug mode...
Building for debugging...
/Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/DidYouGet/DidYouGet/Models/RecordingManager.swift:786:13: warning: variable 'videoSettings' was never mutated; consider changing to 'let' constant
 784 |         // Configure video settings with appropriate parameters
 785 |         // Add additional settings for more reliable encoding
 786 |         var videoSettings: [String: Any] = [
     |             `- warning: variable 'videoSettings' was never mutated; consider changing to 'let' constant
 787 |             AVVideoCodecKey: AVVideoCodecType.h264,
 788 |             AVVideoWidthKey: streamConfig?.width ?? 1920,
[9/9] Applying DidYouGet
Build complete! (6.46s)
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
Created recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
Audio recording is disabled
Refreshing available content...
Configuring stream settings...
Setting frame rate to 60 FPS
Aspect ratio preservation enabled (macOS 14+)
Setting up content filter based on capture type: display
Capturing display 69734662 at 3072 x 1920 (with Retina scaling)
Creating SCStream with configured filter and settings
Checking for existing files at destination paths
✓ Directory is writable: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
✓ Video asset writer created successfully, initial status: 0
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
VIDEO CONFIG: Width=3072, Height=1920, BitRate=20Mbps, FrameRate=60
```



Second launch: 

Same thing, no files. 

```
Building Did You Get It app in debug mode...
Building for debugging...
[1/1] Write swift-version--58304C5D6DBC2206.txt
Build complete! (0.25s)
Build successful!
Running application from: /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/.build/x86_64-apple-macosx/debug/DidYouGet
=== APPLICATION INITIALIZATION ===
Application starting up. macOS Version: Version 15.5 (Build 24F74)
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
WARNING: PreferencesManager not connected to RecordingManager during app init
Initializing RecordingManager
Found persisted recording state: recording was active
Restored video output URL: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_23-14-21/DidYouGetIt_2025-05-20_23-14-21.mov
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
Created recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21/DidYouGetIt_2025-05-20_23-17-21_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21/DidYouGetIt_2025-05-20_23-17-21_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21/DidYouGetIt_2025-05-20_23-17-21.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21/DidYouGetIt_2025-05-20_23-17-21.mov
Audio recording is disabled
Refreshing available content...
Configuring stream settings...
Setting frame rate to 60 FPS
Aspect ratio preservation enabled (macOS 14+)
Setting up content filter based on capture type: display
Capturing display 69734662 at 3072 x 1920 (with Retina scaling)
Creating SCStream with configured filter and settings
Checking for existing files at destination paths
✓ Directory is writable: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-20_23-17-21/DidYouGetIt_2025-05-20_23-17-21.mov
✓ Video asset writer created successfully, initial status: 0
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
VIDEO CONFIG: Width=3072, Height=1920, BitRate=20Mbps, FrameRate=60
```

