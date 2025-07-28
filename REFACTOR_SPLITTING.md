# Refactoring Plan: Splitting Large Swift Files

This document outlines a meticulous, step-by-step plan for a junior software developer to refactor and split the largest Swift code files in the `DidYouGetIt` project into smaller, more focused units. The primary goal is to improve maintainability, readability, and testability without altering the existing functionality.

**Guiding Principles for the Junior Developer:**

1.  **One Change at a Time:** Make small, isolated changes. Test thoroughly after each significant modification.
2.  **Functionality First:** Ensure the application's behavior remains absolutely identical after each step.
3.  **Version Control:** Commit frequently with clear, descriptive messages. Use a dedicated branch for this refactoring.
4.  **Communication:** If unsure, ask for clarification. Document decisions.
5.  **Readability:** Ensure the new structure is intuitive and easy to navigate.

---

## 1. Refactoring `DidYouGet/DidYouGet/Models/RecordingManager.swift`

**Current State:** This file (approx. 40 KB) acts as the central coordinator for the entire recording process. It manages state, interacts with various processors and trackers, handles permissions, content loading, and UI alerts. Its broad responsibilities make it a prime candidate for splitting.

**Goal:** Decompose `RecordingManager` into smaller, single-responsibility components.

**Proposed New Files/Modules:**

*   `RecordingStateController.swift`: Manages the core recording state (`isRecording`, `isPaused`, `recordingDuration`, `startTime`, `isStoppingProcessActive`) and its persistence.
*   `RecordingSessionCoordinator.swift`: Orchestrates the start, stop, pause, and resume logic, delegating to processors and trackers. This will contain the bulk of the `startRecordingAsync` and `stopRecordingAsyncInternal` logic.
*   `ContentLoader.swift`: Handles loading available displays and windows (`loadAvailableContent`).
*   `PermissionService.swift`: Encapsulates permission checks and requests (`checkPermissions`, `checkScreenRecordingPermission`, `requestScreenRecordingPermission`).
*   `AlertPresenter.swift`: Provides a utility for showing UI alerts (`showAlert`).

---

### Step-by-Step Plan for `RecordingManager.swift`

**Phase 1: Extracting `AlertPresenter`**

1.  **Create `AlertPresenter.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Utilities/AlertPresenter.swift`.
    *   Define a `final class AlertPresenter` with a static method `showAlert(title: String, message: String)`.
    *   Move the `showAlert` method's implementation from `RecordingManager.swift` into this new class.
    *   Ensure `import AppKit` or `import Cocoa` is present in `AlertPresenter.swift` if `NSAlert` is used.
    *   **Code to move:**
        ```swift
        // In RecordingManager.swift
        @MainActor
        func showAlert(title: String, message: String) {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        ```
        becomes:
        ```swift
        // In AlertPresenter.swift
        import AppKit // or Cocoa

        final class AlertPresenter {
            @MainActor
            static func showAlert(title: String, message: String) {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        ```
2.  **Update Calls in `RecordingManager.swift`:**
    *   Replace all calls to `showAlert(...)` with `AlertPresenter.showAlert(...)`.
    *   Remove the `showAlert` method from `RecordingManager.swift`.
3.  **Test:** Build and run the application (`./run.sh`). Verify that all alerts (e.g., permission denied, recording errors) still appear correctly.

**Phase 2: Extracting `PermissionService`**

1.  **Create `PermissionService.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Services/PermissionService.swift`.
    *   Define a `final class PermissionService`.
    *   Move `checkPermissions()`, `checkScreenRecordingPermission()`, and `requestScreenRecordingPermission()` methods from `RecordingManager.swift` into `PermissionService.swift`.
    *   Ensure necessary imports (`ScreenCaptureKit`, `AVFoundation` if audio permissions are handled here) are present.
    *   **Code to move:**
        ```swift
        // In RecordingManager.swift
        func checkPermissions() { ... }
        private func checkScreenRecordingPermission() async -> Bool { ... }
        private func requestScreenRecordingPermission() async { ... }
        ```
        becomes:
        ```swift
        // In PermissionService.swift
        import ScreenCaptureKit
        // ... other necessary imports

        final class PermissionService {
            func checkPermissions() { ... }
            func checkScreenRecordingPermission() async -> Bool { ... }
            func requestScreenRecordingPermission() async { ... }
        }
        ```
2.  **Integrate `PermissionService` into `RecordingManager`:**
    *   Add a `private let permissionService = PermissionService()` property to `RecordingManager`.
    *   In `RecordingManager`'s `init()`, replace the direct calls to `checkPermissions()` with `permissionService.checkPermissions()`.
3.  **Test:** Build and run the application. Verify that permission prompts (if applicable) still function correctly and the app starts without permission-related errors.

**Phase 3: Extracting `ContentLoader`**

1.  **Create `ContentLoader.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Services/ContentLoader.swift`.
    *   Define a `final class ContentLoader`.
    *   Move `loadAvailableContent()` from `RecordingManager.swift` into `ContentLoader.swift`.
    *   This method will need to return the `availableDisplays` and `availableWindows`. Consider making it return a tuple or a custom struct.
    *   **Code to move:**
        ```swift
        // In RecordingManager.swift
        func loadAvailableContent() async { ... }
        ```
        becomes:
        ```swift
        // In ContentLoader.swift
        import ScreenCaptureKit

        final class ContentLoader {
            func loadAvailableContent() async -> (displays: [SCDisplay], windows: [SCWindow]) {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    let displays = content.displays
                    let windows = content.windows.filter { window in
                        window.frame.width > 50 && window.frame.height > 50 && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                    }
                    return (displays, windows)
                } catch {
                    print("ERROR: Failed to load available content: \(error)")
                    return ([], [])
                }
            }
        }
        ```
2.  **Integrate `ContentLoader` into `RecordingManager`:**
    *   Add a `private let contentLoader = ContentLoader()` property to `RecordingManager`.
    *   In `RecordingManager`'s `init()` and any other call sites, replace the direct call to `loadAvailableContent()` with `let (displays, windows) = await contentLoader.loadAvailableContent()`.
    *   Update `RecordingManager`'s `@Published var availableDisplays` and `availableWindows` properties by assigning the returned values.
3.  **Test:** Build and run the application. Verify that the display and window selection pickers in the UI are correctly populated.

**Phase 4: Extracting `RecordingStateController`**

This is a more complex extraction as it involves `@Published` properties and `UserDefaults`.

1.  **Create `RecordingStateController.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Models/RecordingStateController.swift`.
    *   Define a `final class RecordingStateController: ObservableObject`.
    *   Move the following `@Published` properties and their `didSet` observers:
        *   `isRecording`
        *   `isPaused`
        *   `recordingDuration`
        *   `isStoppingProcessActive`
    *   Move the `timerPublisher` property.
    *   Move the `loadPersistedRecordingState()`, `resumePersistedRecording()`, and `clearPersistedRecordingState()` methods.
    *   Move the `startTime` property.
    *   **Code to move (simplified):**
        ```swift
        // In RecordingManager.swift
        @Published var isRecording: Bool = false { ... }
        @Published var isPaused: Bool = false { ... }
        @Published var isStoppingProcessActive: Bool = false
        @Published var recordingDuration: TimeInterval = 0
        let timerPublisher = Timer.publish(...)
        private var startTime: Date?
        
        private func loadPersistedRecordingState() { ... }
        private func resumePersistedRecording() { ... }
        private func clearPersistedRecordingState() { ... }
        ```
        becomes:
        ```swift
        // In RecordingStateController.swift
        import Foundation
        import SwiftUI // For @Published

        final class RecordingStateController: ObservableObject {
            @Published var isRecording: Bool = false { ... }
            @Published var isPaused: Bool = false { ... }
            @Published var isStoppingProcessActive: Bool = false
            @Published var recordingDuration: TimeInterval = 0
            let timerPublisher = Timer.publish(...)
            var startTime: Date? // Make internal/public if RecordingSessionCoordinator needs to set it
            
            init() {
                loadPersistedRecordingState()
            }

            func loadPersistedRecordingState() { ... }
            func resumePersistedRecording() { ... }
            func clearPersistedRecordingState() { ... }
            // Add a method to set startTime if needed by coordinator
            func setStartTime(_ date: Date?) { self.startTime = date }
        }
        ```
2.  **Integrate `RecordingStateController` into `RecordingManager`:**
    *   Add a `private let stateController = RecordingStateController()` property to `RecordingManager`.
    *   Replace all direct accesses to `isRecording`, `isPaused`, `recordingDuration`, `isStoppingProcessActive`, `startTime`, `timerPublisher` with `stateController.isRecording`, `stateController.isPaused`, etc.
    *   Remove the moved properties and methods from `RecordingManager`.
    *   Update `RecordingManager`'s `init()` to remove calls to `loadPersistedRecordingState()` and `resumePersistedRecording()` as `RecordingStateController` will handle its own initialization.
    *   Ensure `RecordingManager` can still call `stateController.clearPersistedRecordingState()` when needed.
3.  **Update `ContentView.swift`:**
    *   `ContentView` currently observes `recordingManager.isRecording`, `recordingManager.isPaused`, `recordingManager.recordingDuration`, `recordingManager.isStoppingProcessActive`.
    *   It needs to observe the new `RecordingStateController`.
    *   **Option A (Simpler for now):** Keep `ContentView` observing `RecordingManager`, and `RecordingManager` will forward the `@Published` properties from `RecordingStateController`. This means `RecordingManager` will need to re-publish these properties.
        ```swift
        // In RecordingManager.swift
        @Published var isRecording: Bool { get { stateController.isRecording } set { stateController.isRecording = newValue } }
        // ... repeat for other properties
        ```
        This keeps `ContentView` changes minimal but adds boilerplate to `RecordingManager`.
    *   **Option B (Cleaner, but more `ContentView` changes):** Pass `RecordingStateController` as an `EnvironmentObject` to `ContentView` directly.
        ```swift
        // In DidYouGetApp.swift
        .environmentObject(recordingManager)
        .environmentObject(recordingManager.stateController) // New line
        
        // In ContentView.swift
        @EnvironmentObject var recordingManager: RecordingManager
        @EnvironmentObject var stateController: RecordingStateController // New line
        // Replace recordingManager.isRecording with stateController.isRecording etc.
        ```
        For this refactoring, Option B is preferred for cleaner separation.
4.  **Test:** Build and run the application. Verify that the UI correctly reflects the recording state (Record/Stop button, timer, pause/resume) and that persistence works across app launches.

**Phase 5: Extracting `RecordingSessionCoordinator`**

This will be the largest part of the refactoring for `RecordingManager`.

1.  **Create `RecordingSessionCoordinator.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Services/RecordingSessionCoordinator.swift`.
    *   Define a `final class RecordingSessionCoordinator`.
    *   This class will need dependencies injected: `RecordingStateController`, `PreferencesManager`, `CaptureSessionManager`, `VideoProcessor`, `AudioProcessor`, `MouseTracker`, `KeyboardTracker`, `OutputFileManager`.
    *   Move the core logic of `startRecordingAsync()` and `stopRecordingAsyncInternal()` into this class.
    *   Move `handleSampleBuffer()` into this class (it will need access to `VideoProcessor` and `AudioProcessor`).
    *   Move `startInputTracking()` into this class.
    *   **Code to move (simplified):**
        ```swift
        // In RecordingManager.swift
        func startRecordingAsync() async throws { ... }
        private func stopRecordingAsyncInternal() async throws { ... }
        private func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: SCStreamType) { ... }
        private func startInputTracking() { ... }
        ```
        becomes:
        ```swift
        // In RecordingSessionCoordinator.swift
        import Foundation
        import AVFoundation
        import ScreenCaptureKit
        // ... other necessary imports

        final class RecordingSessionCoordinator {
            private let stateController: RecordingStateController
            private let preferencesManager: PreferencesManager // Injected
            private let captureSessionManager: CaptureSessionManager // Injected
            private let videoProcessor: VideoProcessor // Injected
            private let audioProcessor: AudioProcessor // Injected
            private let mouseTracker: MouseTracker // Injected
            private let keyboardTracker: KeyboardTracker // Injected
            // OutputFileManager is static, so direct call is fine

            init(stateController: RecordingStateController, preferencesManager: PreferencesManager, ...) {
                self.stateController = stateController
                self.preferencesManager = preferencesManager
                // ... assign other injected dependencies
            }

            func startRecordingAsync() async throws {
                // Use stateController.isRecording, stateController.startTime etc.
                // Call captureSessionManager.configureCaptureSession etc.
                // Call videoProcessor.setupVideoWriter etc.
                // Call mouseTracker.startTracking etc.
            }

            func stopRecordingAsyncInternal() async throws {
                // Use stateController.isRecording etc.
                // Call mouseTracker.stopTracking etc.
                // Call videoProcessor.finishWriting etc.
            }

            func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer, type: RecordingManager.SCStreamType) {
                // Use stateController.isPaused
                // Call videoProcessor.processSampleBuffer etc.
            }

            func startInputTracking() {
                // Use preferencesManager.recordMouseMovements etc.
                // Call mouseTracker.startTracking etc.
            }
        }
        ```
2.  **Integrate `RecordingSessionCoordinator` into `RecordingManager`:**
    *   Add a `private var sessionCoordinator: RecordingSessionCoordinator!` property to `RecordingManager`.
    *   In `RecordingManager`'s `init()`, initialize `sessionCoordinator` after all its dependencies (processors, trackers, state controller, preferences manager) are ready.
    *   Replace calls to `startRecordingAsync()`, `stopRecording()`, `handleSampleBuffer()`, `startInputTracking()` with `sessionCoordinator.startRecordingAsync()`, `sessionCoordinator.stopRecording()`, etc.
    *   `RecordingManager.stopRecording()` will now simply call `sessionCoordinator.stopRecording()`.
    *   Remove the moved methods from `RecordingManager`.
3.  **Test:** This is the most critical testing phase. Build and run. Perform full recording cycles: start, record for a duration, move mouse/type keys, stop. Verify video, audio, and JSON files are correctly generated and contain data. Test pause/resume. Test error scenarios (e.g., permissions denied).

**Phase 6: Final Cleanup of `RecordingManager.swift`**

1.  **Review `RecordingManager.swift`:** After all extractions, `RecordingManager` should be much smaller, primarily acting as an orchestrator that holds instances of the new services/controllers and exposes a simplified API to the UI.
2.  **Remove Redundant Properties/Methods:** Delete any properties or methods that have been fully moved to other files.
3.  **Adjust Imports:** Remove unnecessary imports.
4.  **Access Modifiers:** Ensure all remaining properties and methods have appropriate access modifiers (`private`, `internal`, `public`).

---

## 2. Refactoring `DidYouGet/DidYouGet/Models/Recording/VideoProcessor.swift`

**Current State:** This file (approx. 30 KB) handles all aspects of video processing, including `AVAssetWriter` setup, frame processing, and file finalization. It also contains helper logic for timestamp adjustments and fallback frames.

**Goal:** Separate core video writing logic from utility/recovery functions.

**Proposed New Files/Modules:**

*   `VideoWriterService.swift`: Manages the `AVAssetWriter` and `AVAssetWriterInput` lifecycle (setup, start, finish writing).
*   `VideoFrameProcessor.swift`: Handles the `processSampleBuffer` logic, focusing on appending frames to the writer.
*   `VideoRecoveryUtils.swift`: Contains helper functions for adjusting timestamps and creating fallback frames.

---

### Step-by-Step Plan for `VideoProcessor.swift`

**Phase 1: Extracting `VideoRecoveryUtils`**

1.  **Create `VideoRecoveryUtils.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Utilities/VideoRecoveryUtils.swift`.
    *   Define a `final class VideoRecoveryUtils`.
    *   Move `createAndAppendFallbackFrame()` and `adjustSampleBufferTimestamp()` into this class.
    *   These methods will need access to `AVAssetWriterInput` and `AVAssetWriter`. They should be passed as parameters or the `VideoRecoveryUtils` instance should be initialized with them. For `createAndAppendFallbackFrame`, it might be simpler to pass the `videoInput` and `writer` directly.
    *   **Code to move (simplified):**
        ```swift
        // In VideoProcessor.swift
        private func createAndAppendFallbackFrame() -> Bool { ... }
        private func adjustSampleBufferTimestamp(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? { ... }
        ```
        becomes:
        ```swift
        // In VideoRecoveryUtils.swift
        import Foundation
        import AVFoundation
        import CoreMedia

        final class VideoRecoveryUtils {
            // Methods will need videoInput and writer passed in
            static func createAndAppendFallbackFrame(videoInput: AVAssetWriterInput, writer: AVAssetWriter) -> Bool { ... }
            static func adjustSampleBufferTimestamp(_ sampleBuffer: CMSampleBuffer, videoFramesProcessed: Int) -> CMSampleBuffer? { ... }
        }
        ```
2.  **Update Calls in `VideoProcessor.swift`:**
    *   In `processSampleBuffer`, replace calls to `createAndAppendFallbackFrame()` with `VideoRecoveryUtils.createAndAppendFallbackFrame(videoInput: videoInput, writer: writer)`.
    *   Replace calls to `adjustSampleBufferTimestamp()` with `VideoRecoveryUtils.adjustSampleBufferTimestamp(sampleBuffer, videoFramesProcessed: videoFramesProcessed)`.
    *   Remove the moved methods from `VideoProcessor.swift`.
3.  **Test:** Build and run. Test scenarios where fallback frames or timestamp adjustments might occur (e.g., by simulating a dropped first frame if possible, or just ensuring normal recording still works).

**Phase 2: Extracting `VideoWriterService`**

1.  **Create `VideoWriterService.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Services/VideoWriterService.swift`.
    *   Define a `final class VideoWriterService`.
    *   Move `videoAssetWriter`, `videoInput`, `videoOutputURL` properties.
    *   Move `setupVideoWriter()`, `startWriting()`, `startSession(at:)`, and `finishWriting()` methods.
    *   This class will be responsible for the lifecycle of the `AVAssetWriter`.
    *   **Code to move (simplified):**
        ```swift
        // In VideoProcessor.swift
        var videoAssetWriter: AVAssetWriter?
        private var videoInput: AVAssetWriterInput?
        private var videoOutputURL: URL?
        
        func setupVideoWriter(...) throws -> AVAssetWriter { ... }
        func startWriting() -> Bool { ... }
        func startSession(at time: CMTime) { ... }
        func finishWriting() async -> (Bool, Error?) { ... }
        ```
        becomes:
        ```swift
        // In VideoWriterService.swift
        import Foundation
        import AVFoundation
        import ScreenCaptureKit // For PreferencesManager.VideoQuality
        import CoreMedia

        final class VideoWriterService {
            var videoAssetWriter: AVAssetWriter?
            var videoInput: AVAssetWriterInput? // Make internal/public for VideoFrameProcessor
            private var videoOutputURL: URL?

            func setupVideoWriter(...) throws -> AVAssetWriter { ... }
            func startWriting() -> Bool { ... }
            func startSession(at time: CMTime) { ... }
            func finishWriting() async -> (Bool, Error?) { ... }
            func getOutputURL() -> URL? { return videoOutputURL }
        }
        ```
2.  **Integrate `VideoWriterService` into `VideoProcessor` (which will become `VideoFrameProcessor`):**
    *   Rename `VideoProcessor.swift` to `VideoFrameProcessor.swift`.
    *   In `VideoFrameProcessor.swift`, add a `private let writerService = VideoWriterService()` property.
    *   Update `VideoFrameProcessor`'s `init()` to take a `VideoWriterService` instance.
    *   Replace all calls to `setupVideoWriter()`, `startWriting()`, `startSession(at:)`, `finishWriting()` with `writerService.setupVideoWriter()`, `writerService.startWriting()`, etc.
    *   `VideoFrameProcessor` will now primarily focus on `processSampleBuffer`. It will need access to `writerService.videoInput` and `writerService.videoAssetWriter`.
3.  **Update `RecordingSessionCoordinator` (or `RecordingManager` if not yet split):**
    *   The `RecordingSessionCoordinator` will now directly interact with `VideoWriterService` for setup/start/finish.
    *   It will pass the `VideoWriterService` instance to `VideoFrameProcessor`.
4.  **Test:** Build and run. Verify that video recording still works perfectly, files are created, and contain data. Test start/stop cycles.

**Phase 3: Finalizing `VideoFrameProcessor`**

1.  **Review `VideoFrameProcessor.swift`:**
    *   This file should now primarily contain the `processSampleBuffer()` method and the `videoFramesProcessed` counter.
    *   It will depend on `VideoWriterService` to append the buffers.
    *   **Code (simplified):**
        ```swift
        // In VideoFrameProcessor.swift (formerly VideoProcessor)
        final class VideoFrameProcessor {
            private let writerService: VideoWriterService
            private var videoFramesProcessed: Int = 0

            init(writerService: VideoWriterService) {
                self.writerService = writerService
            }

            func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
                // Use writerService.videoInput and writerService.videoAssetWriter
                // Call VideoRecoveryUtils.adjustSampleBufferTimestamp etc.
                // Call writerService.videoInput.append(adjustedBuffer)
            }
            func getFramesProcessed() -> Int { return videoFramesProcessed }
        }
        ```
2.  **Adjust Imports:** Remove unnecessary imports.
3.  **Access Modifiers:** Ensure all remaining properties and methods have appropriate access modifiers.

---

## 3. Refactoring `DidYouGet/DidYouGet/Views/ContentView.swift`

**Current State:** This file (approx. 21 KB) contains the entire main UI of the application, including complex `VStack` and `HStack` layouts, conditional views, and button actions.

**Goal:** Break down the large `ContentView` into smaller, reusable SwiftUI sub-views, each responsible for a specific section of the UI.

**Proposed New Files/Modules:**

*   `RecordingStatusView.swift`: Displays recording duration and status.
*   `ControlButtonsView.swift`: Contains the Record, Stop, Pause/Resume buttons.
*   `CaptureSourceSelectionView.swift`: Manages the capture type picker (Display, Window, Area) and the corresponding source selection pickers.
*   `RecordingOptionsView.swift`: Contains toggles for audio, mouse, and keyboard recording.
*   `BottomActionButtonsView.swift`: Contains "Select Area", "Preferences", and "Quit" buttons.
*   `TimeFormatter.swift`: A utility for formatting `TimeInterval` into a human-readable string.
*   `RecordingAreaSelector.swift`: Encapsulates the `selectArea()` logic.

---

### Step-by-Step Plan for `ContentView.swift`

**Phase 1: Extracting `TimeFormatter`**

1.  **Create `TimeFormatter.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Utilities/TimeFormatter.swift`.
    *   Define a `final class TimeFormatter`.
    *   Move the `timeString(from interval: TimeInterval)` method into this class, making it `static`.
    *   **Code to move:**
        ```swift
        // In ContentView.swift
        private func timeString(from interval: TimeInterval) -> String { ... }
        ```
        becomes:
        ```swift
        // In TimeFormatter.swift
        import Foundation

        final class TimeFormatter {
            static func timeString(from interval: TimeInterval) -> String {
                let minutes = Int(interval) / 60
                let seconds = Int(interval) % 60
                let milliseconds = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
                return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
            }
        }
        ```
2.  **Update Calls in `ContentView.swift`:**
    *   Replace `timeString(from: recordingManager.recordingDuration)` with `TimeFormatter.timeString(from: recordingManager.recordingDuration)`.
3.  **Test:** Build and run. Verify the timer display still functions correctly.

**Phase 2: Extracting `RecordingAreaSelector`**

1.  **Create `RecordingAreaSelector.swift`:**
    *   Create a new Swift file: `DidYouGet/DidYouGet/Services/RecordingAreaSelector.swift`.
    *   Define a `final class RecordingAreaSelector`.
    *   Move the `selectArea()` method's logic into this class.
    *   This class will need access to `RecordingManager` (specifically `selectedScreen` and `recordingArea`). It should be initialized with a reference to `RecordingManager` or take necessary parameters.
    *   It will also need to communicate the `showAreaSelectedConfirmation` and `selectedAreaInfo` back to the UI. This can be done via a completion handler or by making `RecordingAreaSelector` an `ObservableObject` itself. For simplicity, let's pass a closure for confirmation.
    *   **Code to move (simplified):**
        ```swift
        // In ContentView.swift
        private func selectArea() { ... }
        @State private var showAreaSelectedConfirmation = false
        @State private var selectedAreaInfo = ""
        ```
        becomes:
        ```swift
        // In RecordingAreaSelector.swift
        import Foundation
        import CoreGraphics // For CGRect
        import ScreenCaptureKit // For SCDisplay

        final class RecordingAreaSelector {
            private let recordingManager: RecordingManager // Injected

            init(recordingManager: RecordingManager) {
                self.recordingManager = recordingManager
            }

            func selectArea(onAreaSelected: @escaping (String) -> Void) {
                guard let selectedScreen = recordingManager.selectedScreen else { return }
                // ... existing logic ...
                recordingManager.recordingArea = selectedArea
                let info = "Selected area: \(Int(areaWidth))×\(Int(areaHeight)) at (\(Int(areaX)), \(Int(areaY)))"
                onAreaSelected(info)
            }
        }
        ```
2.  **Update Calls in `ContentView.swift`:**
    *   Add a `private let areaSelector: RecordingAreaSelector` property to `ContentView`, initialized in `init()` or `onAppear`.
    *   In the "Select Area" button's action, call `areaSelector.selectArea { info in ... }`.
    *   Manage `showAreaSelectedConfirmation` and `selectedAreaInfo` as `@State` variables in `ContentView` and update them from the closure.
3.  **Test:** Build and run. Verify that the "Select Area" button works and the confirmation message appears.

**Phase 3: Extracting UI Sub-views**

This phase involves creating new SwiftUI `View` files and moving sections of `ContentView`'s `body` into them. Each new view will need to receive its dependencies (e.g., `RecordingManager`, `PreferencesManager`) as `EnvironmentObject`s or `@Binding`s.

1.  **`RecordingStatusView.swift`:**
    *   Create `DidYouGet/DidYouGet/Views/RecordingStatusView.swift`.
    *   Move the `VStack` containing the timer and "Recording/Ready to record" text.
    *   It will need `recordingManager` as an `EnvironmentObject`.
2.  **`ControlButtonsView.swift`:**
    *   Create `DidYouGet/DidYouGet/Views/ControlButtonsView.swift`.
    *   Move the `if !recordingManager.isRecording { ... } else { ... }` block containing the Record, Stop, Pause/Resume buttons.
    *   It will need `recordingManager` and `preferencesManager` as `EnvironmentObject`s.
3.  **`CaptureSourceSelectionView.swift`:**
    *   Create `DidYouGet/DidYouGet/Views/CaptureSourceSelectionView.swift`.
    *   Move the "Capture Source" `HStack` and the `Picker` for capture type, and the `switch` statement for display/window/area selection.
    *   It will need `recordingManager` as an `EnvironmentObject`.
    *   The `showAreaSelectedConfirmation` and `selectedAreaInfo` states will need to be passed down or managed by a parent view. Consider passing them as `@Binding`s from `ContentView`.
4.  **`RecordingOptionsView.swift`:**
    *   Create `DidYouGet/DidYouGet/Views/RecordingOptionsView.swift`.
    *   Move the "Recording Options" `VStack` containing the audio toggle.
    *   It will need `preferencesManager` as an `EnvironmentObject`.
5.  **`BottomActionButtonsView.swift`:**
    *   Create `DidYouGet/DidYouGet/Views/BottomActionButtonsView.swift`.
    *   Move the bottom `HStack` containing "Select Area", "Preferences", and "Quit" buttons.
    *   It will need `recordingManager` as an `EnvironmentObject` (for `captureType` to show/hide "Select Area").
    *   It will need a way to trigger `selectArea()` from `ContentView`. Pass a closure.
6.  **Update `ContentView.swift`:**
    *   Replace the moved blocks in `ContentView`'s `body` with instances of the new sub-views.
    *   Pass necessary `EnvironmentObject`s or `@Binding`s to the new views.
    *   **Example:**
        ```swift
        // In ContentView.swift
        var body: some View {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    RecordingStatusView()
                        .environmentObject(recordingManager)
                        .environmentObject(stateController) // If using Option B for state controller
                    Spacer()
                    ControlButtonsView()
                        .environmentObject(recordingManager)
                        .environmentObject(preferencesManager)
                        .environmentObject(stateController) // If using Option B
                }
                // ... rest of the views
            }
        }
        ```
7.  **Test:** Build and run after each sub-view extraction. Verify that the UI looks identical and all buttons/pickers function as expected.

**Phase 4: Final Cleanup of `ContentView.swift`**

1.  **Review `ContentView.swift`:** It should now be much shorter, primarily focusing on the overall layout and composition of its sub-views.
2.  **Remove Redundant Properties/Methods:** Delete any properties or methods that have been fully moved.
3.  **Adjust Imports:** Remove unnecessary imports.
4.  **Access Modifiers:** Ensure all remaining properties and methods have appropriate access modifiers.

---

This comprehensive plan provides a clear roadmap for refactoring these large files. Remember to commit frequently and test diligently after each step to ensure functionality remains intact.
