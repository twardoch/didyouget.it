1.  **Project Setup and Initial Cleanup:**
    *   Create `PLAN.md` with this detailed plan.
    *   Create `TODO.md` with a summarized checklist.
    *   Create `CHANGELOG.md`.
    *   Review and remove excessive `print` statements used for debugging or make them conditional (e.g., using `#if DEBUG`). Focus on `RecordingManager`, `VideoProcessor`, `AudioProcessor`, `CaptureSessionManager`, `OutputFileManager`.

2.  **MVP Feature Scope - Input Tracking Removal:**
    *   Temporarily disable/remove UI elements related to Mouse and Keyboard tracking in `ContentView.swift` and `PreferencesView.swift`.
    *   Comment out or remove logic related to `MouseTracker` and `KeyboardTracker` in `RecordingManager.swift`.
    *   Exclude `Models/InputTracking/KeyboardTracker.swift` and `Models/InputTracking/MouseTracker.swift` from the build target for MVP.

3.  **Core Recording Logic Review and Refinement:**
    *   **Stream Configuration:** In `CaptureSessionManager.configureCaptureSession`, ensure `SCStreamConfiguration` (especially `minimumFrameInterval`, `width`, `height`, `pixelFormat`) is correctly derived from `PreferencesManager` settings (frame rate, quality) and selected display/window properties, not hardcoded test values.
    *   **Output Format:**
        *   Change video output file type from `.mov` to `.mp4` in `OutputFileManager.swift` and `VideoProcessor.swift` (configure `AVAssetWriter` with `AVFileType.mp4`).
        *   Ensure audio output (if separate) remains `.m4a` or aligns with common standards if changed.
    *   **Permissions Handling:**
        *   Implement proper screen recording permission checks (replace stub in `RecordingManager.checkScreenRecordingPermission`). Request permission if not granted.
        *   Implement proper microphone permission checks if audio recording is enabled. Request permission if not granted.
    *   **Area Selection (MVP Simplification):**
        *   For MVP, if full interactive area selection is too complex, either:
            *   Default to "Full Screen" for the selected display and disable "Area" selection mode in `ContentView.swift`. Add a TODO for future implementation.
            *   Or, clearly label the current "quarter screen" stub in `ContentView.selectArea()` as a temporary fixed region.
        *   Investigate if `SCStreamConfiguration.sourceRect` can be used for more direct area capture in `CaptureSessionManager.swift` to avoid capturing full screen and then cropping, if area selection is kept in any form.
    *   **Window Selection:** Verify and ensure window selection capture mode is functional and robust.
    *   **Retina Scaling:** In `CaptureSessionManager.swift`, ensure the scale factor used for window/area capture is dynamically obtained from `SCDisplay.scaleFactor` rather than a hardcoded value of 2.

4.  **Stability and Error Handling:**
    *   Review the necessity of `CaptureSessionManager.addDummyCapture()`. If it's vital for `ScreenCaptureKit` stability, keep it.
    *   Review error handling and recovery mechanisms (e.g., `VideoProcessor.adjustSampleBufferTimestamp`, `VideoProcessor.createAndAppendFallbackFrame`). Ensure they are robust or simplify if underlying issues are resolved.
    *   Test recording start/stop/pause/resume cycles thoroughly.
    *   Verify `OutputFileManager.cleanupFolderIfEmpty()` behavior.

5.  **Build and Test:**
    *   Perform `./run.sh` (as per `AGENTS.md`) to build and run the app on macOS.
    *   Test core recording functionality:
        *   Screen recording (full screen of selected display).
        *   Optional audio recording (mixed into video).
        *   Verify output file format and content.
        *   Test with different quality settings and frame rates.
    *   Observe console output for any new errors or warnings.

6.  **Documentation and Finalization:**
    *   Update `CHANGELOG.md` with all changes made.
    *   Update `TODO.md` and `PLAN.md` to reflect completed tasks.
    *   Ensure comments in code are relevant and concise.

7.  **Submit Changes:**
    *   Commit changes with a descriptive message.
    *   Use a suitable branch name (e.g., `feature/mvp-streamlining`).
