CURRENT ISSUES: 

No video is created. Analyze the running log below. Analyze all codebase, think very hard and research how to fix the problem. Then incorporate the solution in the codebase. Review your fix, analyze it, find ways to improve it, and do improve. 

Also update CHANGELOG.md and PROJECT.md and TODO.md

```
Building Did You Get It app in debug mode...
Found unhandled resource at /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/DidYouGet/DidYouGet/Resources
[1/1] Planning build
Building for debugging...
[7/7] Applying DidYouGet
Build complete! (2.06s)
Build successful!
Running application from: /Users/adam/Developer/vcs/github.twardoch/pub/didyouget.it/.build/x86_64-apple-macosx/debug/DidYouGet
=== APPLICATION INITIALIZATION ===
Application starting up. macOS Version: Version 15.5 (Build 24F74)
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
No persisted recording was active
PreferencesManager set in RecordingManager: DidYouGet.PreferencesManager
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
Initializing RecordingManager
No persisted recording was active
WARNING: PreferencesManager not connected to RecordingManager during app init
CaptureSessionManager initialized
VideoProcessor initialized
AudioProcessor initialized
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
Base output directory: /Users/adam/Movies
Created/verified recording directory: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49
✓ Successfully tested write permissions in directory
Created recording session marker file with session info
Created placeholder for video file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
Created placeholder for mouse tracking file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_mouse.json
Created placeholder for keyboard tracking file at: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_keyboard.json
Mouse tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_mouse.json
Keyboard tracking path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_keyboard.json
Video output path: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
No separate audio file will be created (mixed with video or audio disabled)
Saved video output URL to UserDefaults: file:///Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
Configuring stream settings...
TEST: Setting frame rate to 5 FPS
TEST: Using default pixel format
TEST: Using default scalesToFit
TEST: Using default preservesAspectRatio
Setting up content filter based on capture type: display
TEST: Capturing display 69734662 at FORCED 320x240, 5FPS, QD=1, default fmt/scale/aspect
VIDEO CONFIG: Width=320, Height=240, Quality=High, FrameRate=60
Adding dummy capture callback for initialization
Initializing capture system with warmup frame...
DEBUG_DUMMY: Using dummyConfig resolution 3072x1920
✓ Received dummy initialization frame
Dummy capture completed successfully
Creating video asset writer with output URL: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
Removed existing video file at /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
✓ Successfully created empty placeholder file at /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
✓ Video asset writer created successfully, initial status: 0
WARNING: AVAssetWriter did not immediately create file on disk
Configuring video input settings
Using video quality: High with bitrate: 20 Mbps
VIDEO CONFIG: Width=320, Height=240, BitRate=20Mbps, FrameRate=60
DEBUG_VP: Attempting to create AVAssetWriterInput...
DEBUG_VP: AVAssetWriterInput creation attempted (videoInput is not nil).
DEBUG_VP: Checking if writer can add videoInput...
DEBUG_VP: Writer can add videoInput. Attempting to add...
DEBUG_VP: writer.add(videoInput) executed.
DEBUG_VP: Attempting to return from setupVideoWriter...
DEBUG: Returned from videoProcessor.setupVideoWriter successfully.
DEBUG: Checking audio preferences...
DEBUG: Audio recording is DISABLED in preferences.
DEBUG: Finished checking audio preferences.
Attempting to start video writer...
Starting video asset writer...
VideoWriter.startWriting() returned true
✓ Video writer started successfully, status: 1
✓ Video writer started.
Attempting to create SCStream...
Creating SCStream with configured filter and settings
SCStreamFrameOutput initialized - ready to receive frames
Screen capture output added successfully (using custom SCStreamFrameOutput)
✓ SCStream created.
Attempting to start video/audio processor sessions...
Starting video writer session at time: 0.0...
✓ Video writer session started successfully
✓ Video file already exists at path
✓ Video/audio processor sessions started.
Attempting to run timer setup on MainActor...
Inside MainActor.run for timer setup.
Saved recording start time to UserDefaults: 2025-05-20 23:54:50 +0000
Starting recording timer at: 2025-05-20 23:54:50 +0000
Setting immediate startTime to 2025-05-20 23:54:50 +0000
Setting initial recordingDuration to 0
Creating timer with captured startTime 2025-05-20 23:54:50 +0000
✓ Dispatch timer created and activated
✓ Timer successfully initialized and started
✓ Timer setup block completed.
Attempting to start capture session (captureSessionManager.startCapture())...
Starting SCStream capture...
Forcing UI refresh for timer
TIMER UPDATE: Recording duration = 0.0180588960647583 seconds
Saved duration 0.0180588960647583 to UserDefaults
TIMER UPDATE: Recording duration = 0.10039389133453369 seconds
Saved duration 0.10039389133453369 to UserDefaults
SCStream capture started successfully
✓ Capture session started.
Attempting to start input tracking...
Accessibility permission status: Granted
Mouse tracking enabled, URL: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_mouse.json
Starting mouse tracking
Keyboard tracking enabled, URL: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_keyboard.json
Starting keyboard tracking
✓ Input tracking started or skipped.
Recording started successfully
TIMER UPDATE: Recording duration = 0.28391897678375244 seconds
Saved duration 0.28391897678375244 to UserDefaults
TIMER UPDATE: Recording duration = 0.3013828992843628 seconds
Saved duration 0.3013828992843628 to UserDefaults
TIMER UPDATE: Recording duration = 0.4007989168167114 seconds
Saved duration 0.4007989168167114 to UserDefaults
TIMER UPDATE: Recording duration = 0.5027589797973633 seconds
Saved duration 0.5027589797973633 to UserDefaults
TIMER UPDATE: Recording duration = 0.6028329133987427 seconds
Saved duration 0.6028329133987427 to UserDefaults
TIMER UPDATE: Recording duration = 0.700395941734314 seconds
Saved duration 0.700395941734314 to UserDefaults
TIMER UPDATE: Recording duration = 0.805351972579956 seconds
Saved duration 0.805351972579956 to UserDefaults
TIMER UPDATE: Recording duration = 0.9032809734344482 seconds
Saved duration 0.9032809734344482 to UserDefaults
TIMER UPDATE: Recording duration = 2.0016539096832275 seconds
TIMER UPDATE: Recording duration = 2.103460907936096 seconds
TIMER UPDATE: Recording duration = 2.200727939605713 seconds
TIMER UPDATE: Recording duration = 2.300870895385742 seconds
TIMER UPDATE: Recording duration = 2.400568962097168 seconds
TIMER UPDATE: Recording duration = 2.503804922103882 seconds
TIMER UPDATE: Recording duration = 2.605338931083679 seconds
TIMER UPDATE: Recording duration = 2.7052669525146484 seconds
TIMER UPDATE: Recording duration = 2.801422953605652 seconds
TIMER UPDATE: Recording duration = 2.9047679901123047 seconds
TIMER UPDATE: Recording duration = 4.00476598739624 seconds
TIMER UPDATE: Recording duration = 4.100448966026306 seconds
TIMER UPDATE: Recording duration = 4.201632976531982 seconds
TIMER UPDATE: Recording duration = 4.301364898681641 seconds
TIMER UPDATE: Recording duration = 4.401627898216248 seconds
TIMER UPDATE: Recording duration = 4.505257964134216 seconds
aTIMER UPDATE: Recording duration = 4.602231979370117 seconds
TIMER UPDATE: Recording duration = 4.705196976661682 seconds
TIMER UPDATE: Recording duration = 4.803446888923645 seconds
TIMER UPDATE: Recording duration = 4.904366970062256 seconds
Saved duration 5.005068898200989 to UserDefaults
Saved duration 5.101233005523682 to UserDefaults
Saved duration 5.205425977706909 to UserDefaults
Saved duration 5.303412914276123 to UserDefaults
Saved duration 5.400997996330261 to UserDefaults
Saved duration 5.500378966331482 to UserDefaults
Saved duration 5.603442907333374 to UserDefaults
Saved duration 5.705450892448425 to UserDefaults
Saved duration 5.803905963897705 to UserDefaults
Saved duration 5.905448913574219 to UserDefaults
TIMER UPDATE: Recording duration = 6.000630974769592 seconds
TIMER UPDATE: Recording duration = 6.102556943893433 seconds
TIMER UPDATE: Recording duration = 6.204855918884277 seconds
TIMER UPDATE: Recording duration = 6.303335905075073 seconds
TIMER UPDATE: Recording duration = 6.4015209674835205 seconds
TIMER UPDATE: Recording duration = 6.5033509731292725 seconds
TIMER UPDATE: Recording duration = 6.603466987609863 seconds
TIMER UPDATE: Recording duration = 6.703114986419678 seconds
TIMER UPDATE: Recording duration = 6.804196000099182 seconds
TIMER UPDATE: Recording duration = 6.90341591835022 seconds
TIMER UPDATE: Recording duration = 8.000663995742798 seconds
TIMER UPDATE: Recording duration = 8.112749934196472 seconds
ContentView onAppear - checking recording state
Recording is active, preserving state
TIMER UPDATE: Recording duration = 8.20462691783905 seconds
TIMER UPDATE: Recording duration = 8.303493976593018 seconds
TIMER UPDATE: Recording duration = 8.401701927185059 seconds
TIMER UPDATE: Recording duration = 8.503464937210083 seconds
TIMER UPDATE: Recording duration = 8.602581977844238 seconds
TIMER UPDATE: Recording duration = 8.702901005744934 seconds
TIMER UPDATE: Recording duration = 8.803000926971436 seconds
TIMER UPDATE: Recording duration = 8.901160955429077 seconds
Stop button clicked - requesting stop via RecordingManager
Stop recording requested via stopRecording()

=== STOPPING RECORDING (INTERNAL) ===

Setting isRecording = false
Cancelling dispatch timer
Explicitly setting recordingDuration to 0 for UI update.
Stopping input tracking
Mouse tracking data saved to: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_mouse.json
Keyboard tracking data saved to: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_keyboard.json
Stopping capture session
Stopping SCStream capture...
Stream capture stopped successfully
Waiting for buffers to flush (0.5s delay)...
Finalizing recording files
Finalizing video file...
PRE-FINALIZE VIDEO FILE SIZE: 0 bytes
CRITICAL WARNING: Video file is empty (0 bytes) before finalization!
WRITER STATE DUMP:
  - Status: 1
  - Error: nil
  - Video frames processed: 0
Marking video input as finished
Video successfully finalized
POST-FINALIZE VIDEO FILE SIZE: 0 bytes
Removed zero-length video file at /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
INFO: No separate audio writer to finalize

=== RECORDING DIAGNOSTICS ===

Video frames processed: 0
Audio samples processed: 0
Checking Video file: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
ERROR: Video file not found at expected location: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49.mov
Checking Mouse tracking file: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_mouse.json
Mouse tracking file size: 22537 bytes
✓ Mouse tracking file successfully saved with size: 22537 bytes
Mouse tracking file created at: 2025-05-20 23:54:50 +0000
Checking Keyboard tracking file: /Users/adam/Movies/DidYouGetIt_2025-05-21_01-54-49/DidYouGetIt_2025-05-21_01-54-49_keyboard.json
Keyboard tracking file size: 417 bytes
✓ Keyboard tracking file successfully saved with size: 417 bytes
Keyboard tracking file created at: 2025-05-20 23:54:50 +0000
Recording stopped successfully (Internal)
stopRecordingAsyncInternal completed successfully.
Proceeding to forceFullReset() after stop attempt.
EMERGENCY: Forcing immediate reset of all recording state
Emergency reset complete - all state variables cleared
stopRecording() finished. UI should reflect stopped state.
```

JSONs are created. But no MOV. 

```
{
  "version": "2.0",
  "recording_start": "2025-05-20T23:54:50Z",
  "threshold_ms": 200,
  "events": [
{
  "timestamp" : 4.388750910758972,
  "modifiers" : [

  ],
  "key" : "a",
  "type" : "tap"
},
{
  "timestamp" : 5.689024925231934,
  "modifiers" : [
    "Command"
  ],
  "key" : "•",
  "type" : "tap"
},
{
  "timestamp" : 5.701756954193115,
  "type" : "tap",
  "key" : "Command",
  "modifiers" : [

  ]
}
  ]
}
```

```
{
  "version": "2.0",
  "recording_start": "2025-05-20T23:54:50Z",
  "threshold_ms": 200,
  "events": [
{
  "timestamp" : 1.9682528972625732,
  "x" : 1223,
  "y" : 82,
  "type" : "move"
},
{
  "type" : "move",
  "x" : 1224,
  "timestamp" : 1.9764599800109863,
  "y" : 82
},
{
  "type" : "move",
  "timestamp" : 1.985190987586975,
  "x" : 1224,
  "y" : 81
},
{
  "type" : "move",
  "timestamp" : 1.9935588836669922,
  "x" : 1225,
  "y" : 81
},
{
  "timestamp" : 2.018394947052002,
  "type" : "move",
  "x" : 1226,
  "y" : 80
},
{
  "timestamp" : 2.019558906555176,
  "x" : 1227,
  "type" : "move",
  "y" : 79
},
{
  "timestamp" : 2.019619941711426,
  "type" : "move",
  "x" : 1228,
  "y" : 78
},
{
  "timestamp" : 2.024791955947876,
  "x" : 1229,
  "type" : "move",
  "y" : 77
},
{
  "timestamp" : 2.032862901687622,
  "y" : 77,
  "type" : "move",
  "x" : 1229
},
{
  "timestamp" : 2.0416489839553833,
  "x" : 1230,
  "y" : 75,
  "type" : "move"
},
{
  "timestamp" : 2.0494929552078247,
  "x" : 1231,
  "y" : 75,
  "type" : "move"
},
{
  "x" : 1231,
  "timestamp" : 2.057474970817566,
  "y" : 75,
  "type" : "move"
},
{
  "timestamp" : 2.065451979637146,
  "x" : 1231,
  "y" : 74,
  "type" : "move"
},
{
  "timestamp" : 2.0740429162979126,
  "x" : 1232,
  "y" : 74,
  "type" : "move"
},
{
  "timestamp" : 2.0980859994888306,
  "x" : 1231,
  "y" : 76,
  "type" : "move"
},
{
  "timestamp" : 2.1179949045181274,
  "type" : "move",
  "x" : 1223,
  "y" : 84
},
{
  "timestamp" : 2.1183139085769653,
  "x" : 1215,
  "type" : "move",
  "y" : 93
},
{
  "timestamp" : 2.1220459938049316,
  "x" : 1202,
  "y" : 105,
  "type" : "move"
},
{
  "timestamp" : 2.131338953971863,
  "type" : "move",
  "x" : 1187,
  "y" : 118
},
{
  "timestamp" : 2.1385329961776733,
  "x" : 1166,
  "y" : 135,
  "type" : "move"
},...
```

