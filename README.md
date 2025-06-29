# Did You Get It

**Did You Get It** is a high-performance screen recording application for macOS, designed with a minimal user interface to stay out of your way while providing powerful capture capabilities. It allows you to record your screen at high fidelity, optionally include audio, and track mouse and keyboard inputs with precision.

## Table of Contents

1.  [Overview](#overview)
    *   [What it Does](#what-it-does)
    *   [Who It's For](#who-its-for)
    *   [Why It's Useful](#why-its-useful)
2.  [Installation](#installation)
    *   [Manual Installation (DMG)](#manual-installation-dmg)
    *   [Homebrew (Coming Soon)](#homebrew-coming-soon)
3.  [Usage](#usage)
    *   [Graphical User Interface (GUI)](#graphical-user-interface-gui)
    *   [Command-Line Interface (CLI)](#command-line-interface-cli)
    *   [Programmatic Usage](#programmatic-usage)
4.  [Features](#features)
5.  [Technical Deep Dive](#technical-deep-dive)
    *   [How It Works](#how-it-works)
        *   [Application Core](#application-core)
        *   [User Interface (SwiftUI)](#user-interface-swiftui)
        *   [Configuration Management](#configuration-management)
        *   [Screen and Audio Capture (ScreenCaptureKit)](#screen-and-audio-capture-screencapturekit)
        *   [Video Processing (AVFoundation)](#video-processing-avfoundation)
        *   [Audio Processing (AVFoundation)](#audio-processing-avfoundation)
        *   [Mouse and Keyboard Tracking (CGEventTap)](#mouse-and-keyboard-tracking-cgeventtap)
        *   [Output File Management](#output-file-management)
    *   [Permissions Required](#permissions-required)
6.  [Building from Source](#building-from-source)
7.  [Contributing](#contributing)
    *   [Coding Conventions](#coding-conventions)
    *   [Project Documentation](#project-documentation)
    *   [Testing](#testing)
    *   [Contribution Workflow](#contribution-workflow)
8.  [Troubleshooting](#troubleshooting)
9.  [License](#license)

## Overview

### What it Does

"Did You Get It" is a macOS application focused on creating high-quality screen recordings. It can capture:

*   **Video:** Full-resolution (Retina) video of a selected screen, a specific window, or a custom rectangular area, at up to 60 frames per second.
*   **Audio (Optional):** Audio from a selectable input device. This can be mixed directly into the video file or saved as a separate audio file.
*   **Mouse Movements & Clicks (Optional):** Detailed tracking of mouse movements, clicks (distinguishing between quick clicks and press-hold-release actions), and drags, saved in a JSON format.
*   **Keyboard Strokes (Optional):** Comprehensive logging of keyboard activity, including individual key taps, key holds, and releases, along with modifier key states, also saved in JSON format. Sensitive input can be masked.

The application operates from the macOS menu bar, emphasizing a minimal UI to reduce on-screen clutter during recording.

### Who It's For

This tool is designed for users who need precise and detailed screen recordings, such as:

*   **Developers:** For debugging, demonstrating bugs, or documenting complex UI interactions.
*   **QA Testers:** For creating detailed bug reports with exact reproduction steps.
*   **Educators & Trainers:** For creating high-quality tutorials and instructional videos.
*   **UX/UI Designers:** For analyzing user interactions with prototypes or existing software.
*   **Support Professionals:** For visually guiding users through troubleshooting steps.
*   Anyone needing to document on-screen activity with a high degree of accuracy, including input events.

### Why It's Useful

"Did You Get It" offers several advantages:

*   **High Fidelity:** Records at high frame rates (up to 60 FPS) and supports full Retina display resolutions, ensuring clear and smooth videos.
*   **Detailed Input Tracking:** The optional mouse and keyboard tracking provides invaluable context by capturing not just what happened on screen, but *how* it happened (e.g., a quick click vs. a long press, specific key combinations).
*   **Flexibility:** Users can choose to record entire displays, specific application windows, or custom-defined areas. Audio and input tracking are optional and configurable.
*   **Minimal Intrusion:** The menu bar-based UI stays out of the way, allowing for a clean recording environment.
*   **Organized Output:** Recordings are saved in timestamped folders, keeping video, audio (if separate), and input data neatly organized.

## Installation

### Manual Installation (DMG)

1.  Download the latest `.dmg` file from the [Releases Page](https://github.com/twardoch/didyouget.it/releases).
2.  Open the DMG file.
3.  Drag the "Did You Get It.app" icon into your Applications folder.
4.  Launch the app from your Applications folder or via Spotlight.

### Homebrew (Coming Soon)

Installation via Homebrew is planned:
```bash
brew install --cask didyougetit # Tentative command
```

## Usage

### Graphical User Interface (GUI)

"Did You Get It" is primarily a GUI-driven application.

1.  **Launch:** Open the application. Its icon (a record circle) will appear in the macOS menu bar.
2.  **Controls:** Click the menu bar icon to open the main control window.
    *   **Start/Stop Recording:** Use the "Record" button or the keyboard shortcut `⌘⇧R`.
    *   **Pause/Resume:** While recording, use the pause button or `⌘⇧P`.
    *   **Capture Source:** Select whether to record a full display, a specific window, or a custom area.
        *   For "Area" mode, use the "Select Area..." button to define the region.
    *   **Quick Options:** Toggle audio, mouse, and keyboard recording directly from the main window.
3.  **Preferences:** Access detailed settings via the "Preferences" button (`⌘,`) in the main window or through the app's settings menu. Here you can configure:
    *   Video frame rate and quality.
    *   Audio input device and whether to mix audio with video or save separately.
    *   Default save location.
4.  **Output:** Recordings are saved by default in your `Movies` folder, each within a uniquely named subfolder (e.g., `DidYouGetIt_YYYY-MM-DD_HH-MM-SS`).

### Command-Line Interface (CLI)

The application is not designed for direct CLI control of recording operations. However, the `run.sh` script in the repository can be used by developers to build and run the app in debug mode:
```bash
./run.sh
```
This is primarily for development and testing purposes.

### Programmatic Usage

"Did You Get It" is an end-user application and is not intended to be used as a software library or SDK for programmatic integration into other applications.

## Features

*   **Screen Recording:**
    *   Capture entire displays, specific windows, or custom rectangular areas.
    *   Up to 60 FPS recording.
    *   Full Retina resolution support.
    *   Hardware-accelerated H.264 video encoding.
*   **Audio Recording (Optional):**
    *   Selectable audio input device.
    *   Option to mix audio into the video file (MP4 container with AAC audio).
    *   Option to save audio as a separate M4A file.
*   **Mouse Tracking (Optional):**
    *   Records mouse movements, left/right clicks, press/hold events, and drag actions.
    *   Distinguishes between a quick "click" and a longer "press" followed by a "release" (default threshold: 200ms).
    *   Outputs data to a human-readable JSON file (`_mouse.json`).
*   **Keyboard Tracking (Optional):**
    *   Records key taps, key holds, and key releases, including modifier keys (Shift, Command, Option, Control, Function, CapsLock).
    *   Distinguishes between a quick "tap" and a longer "hold" followed by a "release" (default threshold: 200ms).
    *   Option to mask sensitive input (e.g., characters typed in password fields appear as '•').
    *   Outputs data to a human-readable JSON file (`_keyboard.json`).
*   **User Interface:**
    *   Minimal menu bar application.
    *   Quick access to recording controls and basic options.
    *   Comprehensive preferences window for detailed configuration.
*   **Output:**
    *   Video saved as `.mov` (soon to be `.mp4`).
    *   Recordings organized into timestamped folders.
    *   Configurable video quality and save location.
*   **Performance:**
    *   Leverages ScreenCaptureKit and AVFoundation for efficient, hardware-accelerated capture and encoding.
    *   Designed for low CPU and memory footprint during recording.

## Technical Deep Dive

### How It Works

"Did You Get It" is a Swift application built using modern macOS frameworks.

#### Application Core

*   **Entry Point (`DidYouGetApp.swift`):** The application lifecycle is managed by SwiftUI's `App` protocol. It sets up a `MenuBarExtra` to provide the menu bar icon and access to the main `ContentView`.
*   **Central Coordinator (`RecordingManager.swift`):** This is the heart of the application, an `ObservableObject` that manages the recording state (start, stop, pause, resume), coordinates the different components (capture, processing, tracking), and publishes state changes to the UI. It interacts with `CaptureSessionManager`, `VideoProcessor`, `AudioProcessor`, `MouseTracker`, and `KeyboardTracker`.

#### User Interface (SwiftUI)

*   **Main Controls (`ContentView.swift`):** A SwiftUI view that provides buttons to start/stop/pause recording, select the capture source (display, window, area), and toggle quick options. It observes the `RecordingManager` for state updates.
*   **Preferences (`PreferencesView.swift`):** A tabbed SwiftUI view for configuring detailed application settings, such as video quality, frame rate, audio devices, and output locations. It interacts with the `PreferencesManager`.

#### Configuration Management

*   **Settings Storage (`PreferencesManager.swift`):** An `ObservableObject` that uses `@AppStorage` to persist user preferences (e.g., frame rate, video quality, audio settings, default save location). These preferences are read by `RecordingManager` and other components to configure their behavior.

#### Screen and Audio Capture (ScreenCaptureKit)

*   **Capture Setup (`CaptureSessionManager.swift`):**
    *   Uses `ScreenCaptureKit` (specifically `SCStream`) for high-performance, low-overhead capture of screen content and system audio.
    *   An `SCStreamConfiguration` object is configured based on user selections:
        *   **Capture Target:** Full display (`SCDisplay`), specific window (`SCWindow`), or a region of a display.
        *   **Dimensions & Frame Rate:** Sets the output resolution and target frame rate (e.g., 60 FPS via `minimumFrameInterval`).
        *   **Audio:** `capturesAudio` is enabled if audio recording is requested, and `excludesCurrentProcessAudio` is set to true.
    *   An `SCContentFilter` is created to specify what content to capture (e.g., a particular display, a single window).
*   **Sample Buffer Handling (`SCStreamFrameOutput.swift` & `RecordingManager.swift`):**
    *   `SCStreamFrameOutput` is a custom class conforming to the `SCStreamOutput` protocol. It's added as an output to the `SCStream`.
    *   The `stream(_:didOutputSampleBuffer:ofType:)` delegate method in `SCStreamFrameOutput` receives raw `CMSampleBuffer` objects for video frames and audio samples from `SCStream`.
    *   These buffers are then passed to `RecordingManager.handleSampleBuffer`, which routes them to `VideoProcessor` or `AudioProcessor` based on their type (`.screen` or `.audio`).

#### Video Processing (AVFoundation)

*   **Video Encoding (`VideoProcessor.swift`):**
    *   Receives screen `CMSampleBuffer`s from the `RecordingManager`.
    *   Uses an `AVAssetWriter` configured for `.mov` (H.264 video codec).
    *   An `AVAssetWriterInput` is set up with video settings (resolution, H.264 codec, bitrate based on selected quality).
    *   `expectsMediaDataInRealTime` is set to `true`.
    *   The `VideoProcessor` appends incoming `CMSampleBuffer`s to this input. `AVAssetWriter` handles the encoding and writing to the output file.
    *   It initiates the writing process with `startWriting()` and `startSession(atSourceTime:)`, and finalizes the file with `finishWriting()`.

#### Audio Processing (AVFoundation)

*   **Audio Encoding (`AudioProcessor.swift`):**
    *   Receives audio `CMSampleBuffer`s from the `RecordingManager`.
    *   **Mixed Audio:** If audio is to be mixed with video, `AudioProcessor` configures an additional `AVAssetWriterInput` (for AAC audio) and adds it to the `VideoProcessor`'s `AVAssetWriter`. The audio buffers are then appended to this input.
    *   **Separate Audio:** If audio is to be saved separately, `AudioProcessor` creates its own `AVAssetWriter` (configured for `.m4a` file type with AAC audio) and appends audio buffers to its input.
    *   Like `VideoProcessor`, it uses `startWriting()`, `startSession(atSourceTime:)`, and `finishWriting()`.
*   **Device Management (`AudioManager.swift`):** A utility class to list available audio input devices using Core Audio (`AudioObjectGetPropertyData` with selectors like `kAudioHardwarePropertyDevices`) and identify the default input device. This populates the audio device selection UI.

#### Mouse and Keyboard Tracking (CGEventTap)

These trackers run on the main actor and use `CGEventTap` to monitor system-wide input events. They require Accessibility permissions.

*   **Mouse Tracking (`MouseTracker.swift`):**
    *   Creates a `CGEventTap` for mouse events: `mouseMoved`, `leftMouseDown`/`Up`, `rightMouseDown`/`Up`, `leftMouseDragged`/`RightMouseDragged`.
    *   Events are processed to determine:
        *   `move`: Simple mouse position change.
        *   `click`: Mouse button pressed and released within a short threshold (200ms).
        *   `press`: Mouse button pressed and held.
        *   `release`: Mouse button released after being held.
        *   `drag`: Mouse movement while a button is held down.
    *   Each event is timestamped relative to the recording start time and includes coordinates and button type.
    *   Events are written to a JSON file (`_mouse.json`) as they occur. The JSON structure includes a version, recording start time, click threshold, and an array of event objects.
*   **Keyboard Tracking (`KeyboardTracker.swift`):**
    *   Creates a `CGEventTap` for keyboard events: `keyDown`, `keyUp`, `flagsChanged` (for modifier keys).
    *   Events are processed to determine:
        *   `tap`: Key pressed and released within a short threshold (200ms).
        *   `hold`: Key pressed and held.
        *   `release`: Key released after being held.
    *   Handles modifier keys (Shift, Control, Option, Command, Function, CapsLock) by tracking their state via `flagsChanged` events and including active modifiers in each key event.
    *   Converts key codes to human-readable key names (e.g., "A", "Return", "Space").
    *   Includes an option to mask sensitive input: if enabled, characters typed (e.g., in password fields, often toggled by Tab/Return) are recorded as '•'.
    *   Each event is timestamped and includes the key name and active modifiers.
    *   Events are written to a JSON file (`_keyboard.json`) with a similar structure to mouse events.

#### Output File Management

*   **File Organization (`OutputFileManager.swift`):**
    *   For each recording session, creates a unique directory named `DidYouGetIt_YYYY-MM-DD_HH-MM-SS` inside the user's selected save location (defaulting to `~/Movies`).
    *   Generates `URL`s for:
        *   Video file (e.g., `DidYouGetIt_YYYY-MM-DD_HH-MM-SS.mov`).
        *   Separate audio file if applicable (e.g., `DidYouGetIt_YYYY-MM-DD_HH-MM-SS_audio.m4a`).
        *   Mouse tracking data (e.g., `DidYouGetIt_YYYY-MM-DD_HH-MM-SS_mouse.json`).
        *   Keyboard tracking data (e.g., `DidYouGetIt_YYYY-MM-DD_HH-MM-SS_keyboard.json`).
    *   Includes logic to verify output files after recording and clean up empty folders.

### Permissions Required

To function fully, "Did You Get It" requires the following permissions, which macOS will prompt the user to grant when features are first used:

1.  **Screen Recording:** Necessary for capturing the screen content. Prompted when recording starts.
2.  **Microphone Access:** Necessary if audio recording is enabled. Prompted when recording with audio starts.
3.  **Accessibility Access:** Necessary for `MouseTracker` and `KeyboardTracker` to capture mouse and keyboard events system-wide. Prompted if mouse/keyboard tracking is enabled and recording starts. Users can grant this in `System Settings > Privacy & Security > Accessibility`.

## Building from Source

### Requirements

*   Xcode 15.0 or later
*   Swift 6.0 or later (as per project configuration)
*   macOS 12.3 (Monterey) or later (due to ScreenCaptureKit usage)

### Build Steps

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/twardoch/didyouget.it.git
    cd didyouget.it
    ```

2.  **Build using the Makefile (Recommended for development):**
    *   To build and run in debug mode:
        ```bash
        make run
        # or directly ./run.sh
        ```
    *   To create a release build (unsigned):
        ```bash
        make build
        ```
    *   To create a full release build (requires code signing setup):
        ```bash
        make release
        ```

3.  **Build using Swift Package Manager (Alternative):**
    *   Open `Package.swift` in Xcode and build from there.
    *   Or, from the command line:
        ```bash
        swift build -c release
        ```
        The output binary will be in `.build/release/DidYouGetIt`.

## Contributing

Contributions are welcome! Please adhere to the following guidelines.

### Coding Conventions

*   Follow standard Swift coding conventions and SwiftUI best practices.
*   Maintain the existing code style and organization.
*   Prioritize clarity, performance, and maintainability.
*   Ensure code is compatible with the target macOS version specified in `SPEC.MD`.

### Project Documentation

*   **`SPEC.md`:** Contains the detailed technical specification. Please consult this document for design and feature requirements.
*   **`AGENTS.md` / `CLAUDE.md`:** Contains operational instructions for AI agents working on the codebase. Human contributors should also be aware of these guidelines.
*   **`PROGRESS.md`:** Tracks the overall project progress. Update relevant items.
*   **`CHANGELOG.md`:** Document user-visible changes here.
*   **`TODO.md`:** Lists high-priority issues. Check and update as you work.
*   Keep inline code comments updated and write clear commit messages.

### Testing

*   After making changes, run the application using `./run.sh` (or `make run`) on macOS.
*   Thoroughly test the features you've modified or added.
*   Observe console output for any errors or warnings.
*   Ensure the core functionalities (video recording, audio, input tracking if applicable) work as expected.

### Contribution Workflow

1.  **Fork the repository** on GitHub.
2.  **Create a feature branch** from `main`: `git checkout -b feature/your-amazing-feature`.
3.  **Make your changes** and commit them with descriptive messages.
4.  **Push your branch** to your fork: `git push origin feature/your-amazing-feature`.
5.  **Open a Pull Request** against the `main` branch of the original repository.
6.  Clearly describe your changes in the Pull Request and link any relevant issues.

## Troubleshooting

### Common Issues

*   **App doesn't start recording / "No display selected" error:**
    *   Ensure you've granted Screen Recording permission in `System Settings > Privacy & Security > Screen Recording`.
    *   Make sure a display or window is correctly selected in the app's UI before starting.
    *   Check that no other screen recording apps are conflicting.
*   **No audio in recordings:**
    *   Verify Microphone permission is granted in `System Settings > Privacy & Security > Microphone`.
    *   Ensure the correct audio input device is selected in the app's Preferences.
    *   If saving audio separately, check for the `_audio.m4a` file.
*   **Mouse/Keyboard tracking not working:**
    *   Grant Accessibility permission in `System Settings > Privacy & Security > Accessibility`. You may need to add "Did You Get It.app" to the list.
    *   Restart the "Did You Get It" app after granting Accessibility permission.
*   **Video file is empty or very small (0KB):**
    *   This can indicate an issue with the `AVAssetWriter` setup or the `ScreenCaptureKit` stream.
    *   Check console logs for errors related to `VideoProcessor`, `CaptureSessionManager`, or `AVFoundation`.
    *   Ensure the selected recording area or window is valid and visible.

### Getting Help

*   Check the project's [GitHub Issues](https://github.com/twardoch/didyouget.it/issues) for existing reports.
*   If you encounter a new bug, please [file a new issue](https://github.com/twardoch/didyouget.it/issues/new) with detailed steps to reproduce, expected behavior, and actual behavior. Include console logs if relevant.

## License

"Did You Get It" is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
