# 7. Advanced Usage

## Automation and Scripting

### AppleScript Integration

#### Recording Control via AppleScript
Did You Get It provides comprehensive AppleScript support for workflow automation:

```applescript
-- Start recording with custom configuration
tell application "Did You Get It"
    start recording with properties {
        recording area: {x:100, y:100, width:1200, height:800},
        frame rate: 60,
        include system audio: true,
        include microphone: false,
        output location: "~/Desktop/Recordings/"
    }
end tell

-- Stop recording and get file paths
tell application "Did You Get It"
    set recording_files to stop recording
    return recording_files
end tell

-- Get current recording status
tell application "Did You Get It"
    set current_status to recording status
    set recording_time to recording duration
    
    if current_status is "recording" then
        display notification "Recording in progress: " & recording_time
    end if
end tell
```

#### Advanced AppleScript Examples
```applescript
-- Automated testing scenario
on run
    tell application "Did You Get It"
        -- Configure for high-precision input tracking
        set configuration to {
            recording area: entire screen,
            frame rate: 60,
            mouse precision: "high",
            keyboard tracking: true,
            include system audio: true
        }
        
        start recording with properties configuration
        
        -- Wait for external test completion signal
        repeat while recording status is "recording"
            delay 1
            if (do shell script "test -f /tmp/stop_recording && echo 'true' || echo 'false'") is "true" then
                exit repeat
            end if
        end repeat
        
        set output_files to stop recording
        
        -- Process the recorded data
        repeat with file_path in output_files
            if file_path contains "mouse_events.json" then
                do shell script "python3 ~/Scripts/analyze_mouse_data.py " & quoted form of file_path
            end if
        end repeat
    end tell
end run
```

### Shortcuts App Integration

#### Shortcuts Actions
```swift
// Custom shortcuts intent for recording control
class StartRecordingIntent: INIntent {
    @NSManaged public var recordingArea: RecordingAreaType
    @NSManaged public var frameRate: NSNumber?
    @NSManaged public var includeAudio: NSNumber?
    @NSManaged public var outputLocation: String?
}

@available(iOS 16.0, macOS 13.0, *)
struct StartRecordingShortcut: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Starts a new recording session with specified parameters")
    
    @Parameter(title: "Recording Area", default: .fullScreen)
    var recordingArea: RecordingAreaType
    
    @Parameter(title: "Frame Rate", default: 60)
    var frameRate: Int
    
    @Parameter(title: "Include System Audio", default: true)
    var includeAudio: Bool
    
    func perform() async throws -> some IntentResult {
        let configuration = RecordingConfiguration(
            area: recordingArea.area,
            frameRate: frameRate,
            systemAudio: includeAudio
        )
        
        try await RecordingManager.shared.startRecording(with: configuration)
        
        return .result(dialog: "Recording started successfully")
    }
}
```

### Command Line Interface

#### CLI Installation and Setup
```bash
# Install CLI tool (if distributed separately)
brew install didyougetit-cli

# Or use built-in CLI functionality
alias dygi='/Applications/Did\ You\ Get\ It.app/Contents/MacOS/CLI/dygi'

# Basic usage
dygi start --area=screen --fps=60 --audio=system
dygi stop
dygi status
```

#### CLI Command Reference
```bash
# Start recording with specific parameters
dygi record \
    --area="0,0,1920,1080" \
    --display=1 \
    --fps=60 \
    --audio=system,microphone \
    --output="~/Recordings/" \
    --name="test_session"

# Stop current recording
dygi stop

# Query recording status
dygi status --json
# Output: {"status": "recording", "duration": 45.2, "fps": 60}

# List available displays and audio devices
dygi devices
dygi audio-devices

# Export recorded session to different formats
dygi export \
    --session="~/Recordings/test_session" \
    --video-format=mp4 \
    --audio-format=wav \
    --data-format=csv

# Batch processing
dygi batch-process \
    --input-dir="~/Recordings/" \
    --script="~/Scripts/process_recording.py" \
    --parallel=4
```

#### CLI Configuration File
```yaml
# ~/.config/didyougetit/config.yaml
default_settings:
  recording:
    frame_rate: 60
    resolution: "native"
    show_cursor: true
  audio:
    system_audio: true
    microphone: false
    sample_rate: 48000
  input_tracking:
    mouse_precision: "standard"
    keyboard_tracking: true
  output:
    location: "~/Recordings"
    organization: "by_date"
    naming_template: "{date}_{time}_{duration}"

profiles:
  development:
    recording:
      frame_rate: 30
      resolution: "1080p"
    input_tracking:
      mouse_precision: "high"
  
  presentation:
    recording:
      frame_rate: 24
      show_cursor: false
    audio:
      microphone: true
```

## Integration with Development Tools

### IDE Integration

#### Xcode Integration
```swift
// Xcode build phase script for automated testing recordings
#!/bin/bash

# Start recording before running tests
/Applications/Did\ You\ Get\ It.app/Contents/MacOS/CLI/dygi start \
    --area=screen \
    --fps=30 \
    --audio=system \
    --name="test_run_$(date +%Y%m%d_%H%M%S)" &

RECORDING_PID=$!

# Run tests
xcodebuild test -scheme MyApp -destination 'platform=macOS'

# Stop recording
kill $RECORDING_PID
/Applications/Did\ You\ Get\ It.app/Contents/MacOS/CLI/dygi stop

# Process test results with recorded data
python3 Scripts/correlate_test_results.py \
    --test-results="$TEST_RESULTS_PATH" \
    --recording-data="$RECORDING_PATH"
```

#### Visual Studio Code Extension
```typescript
// VSCode extension integration example
import * as vscode from 'vscode';
import { exec } from 'child_process';

export function activate(context: vscode.ExtensionContext) {
    let startRecording = vscode.commands.registerCommand('didyougetit.startRecording', () => {
        const config = vscode.workspace.getConfiguration('didyougetit');
        const recordingArea = config.get('recordingArea', 'screen');
        const frameRate = config.get('frameRate', 60);
        
        exec(`dygi start --area=${recordingArea} --fps=${frameRate}`, (error, stdout, stderr) => {
            if (error) {
                vscode.window.showErrorMessage(`Recording failed: ${error.message}`);
                return;
            }
            vscode.window.showInformationMessage('Recording started');
        });
    });
    
    context.subscriptions.push(startRecording);
}
```

### CI/CD Pipeline Integration

#### GitHub Actions Workflow
```yaml
# .github/workflows/ui-testing-with-recording.yml
name: UI Testing with Screen Recording

on:
  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'

jobs:
  ui-tests-with-recording:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Did You Get It
      run: |
        # Install or configure Did You Get It for CI
        curl -L https://github.com/twardoch/didyougetit-mac/releases/latest/download/DidYouGetIt-CLI.zip -o cli.zip
        unzip cli.zip
        chmod +x dygi
        
    - name: Run UI Tests with Recording
      run: |
        # Start recording
        ./dygi start --area=screen --fps=30 --name="ui_test_${{ github.run_number }}" &
        RECORDING_PID=$!
        
        # Run UI tests
        npm run test:ui
        
        # Stop recording
        kill $RECORDING_PID
        ./dygi stop
        
    - name: Upload Recording Artifacts
      uses: actions/upload-artifact@v3
      if: failure()
      with:
        name: ui-test-recordings
        path: ~/Recordings/ui_test_*
        retention-days: 7
```

#### Jenkins Pipeline
```groovy
pipeline {
    agent { label 'macos' }
    
    stages {
        stage('Setup Recording') {
            steps {
                script {
                    sh '''
                        # Configure recording for test environment
                        dygi config set --profile=ci \
                            --frame-rate=24 \
                            --resolution=1080p \
                            --audio=false \
                            --output="/tmp/recordings"
                    '''
                }
            }
        }
        
        stage('Run Tests with Recording') {
            steps {
                script {
                    try {
                        sh 'dygi start --profile=ci --name="build_${BUILD_NUMBER}"'
                        sh 'make test-ui'
                    } finally {
                        sh 'dygi stop'
                        
                        // Archive recordings for failed tests
                        if (currentBuild.result == 'FAILURE') {
                            archiveArtifacts artifacts: '/tmp/recordings/**/*', fingerprint: true
                        }
                    }
                }
            }
        }
    }
}
```

## Data Analysis and Processing

### JSON Data Processing

#### Python Analysis Scripts
```python
#!/usr/bin/env python3
"""
Analyze mouse and keyboard interaction data from Did You Get It recordings.
"""

import json
import pandas as pd
import numpy as np
from datetime import datetime
import matplotlib.pyplot as plt

class RecordingAnalyzer:
    def __init__(self, session_path):
        self.session_path = session_path
        self.mouse_data = self.load_mouse_data()
        self.keyboard_data = self.load_keyboard_data()
        
    def load_mouse_data(self):
        """Load and parse mouse events JSON."""
        with open(f"{self.session_path}/input_data/mouse_events.json", 'r') as f:
            data = json.load(f)
        
        df = pd.DataFrame(data['mouse_events'])
        df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
        return df
    
    def analyze_click_patterns(self):
        """Analyze clicking behavior patterns."""
        clicks = self.mouse_data[self.mouse_data['type'] == 'click']
        
        # Calculate click frequency over time
        click_frequency = clicks.groupby(clicks['timestamp'].dt.floor('1min')).size()
        
        # Identify click hotspots
        hotspots = clicks.groupby(['x', 'y']).size().sort_values(ascending=False).head(10)
        
        return {
            'total_clicks': len(clicks),
            'click_frequency': click_frequency.to_dict(),
            'hotspots': hotspots.to_dict()
        }
    
    def generate_heatmap(self, output_path="mouse_heatmap.png"):
        """Generate mouse movement heatmap."""
        moves = self.mouse_data[self.mouse_data['type'] == 'move']
        
        plt.figure(figsize=(12, 8))
        plt.hexbin(moves['x'], moves['y'], gridsize=50, cmap='hot')
        plt.colorbar(label='Movement Frequency')
        plt.title('Mouse Movement Heatmap')
        plt.xlabel('X Coordinate')
        plt.ylabel('Y Coordinate')
        plt.savefig(output_path, dpi=300, bbox_inches='tight')
        
    def export_for_ux_analysis(self, output_path="ux_analysis.csv"):
        """Export data in format suitable for UX analysis tools."""
        # Combine mouse and keyboard events with timing
        events = []
        
        for _, row in self.mouse_data.iterrows():
            events.append({
                'timestamp': row['timestamp'],
                'event_type': 'mouse',
                'action': row['type'],
                'x': row.get('x'),
                'y': row.get('y'),
                'details': json.dumps(row.to_dict())
            })
        
        for _, row in self.keyboard_data.iterrows():
            events.append({
                'timestamp': row['timestamp'],
                'event_type': 'keyboard',
                'action': row['type'],
                'x': None,
                'y': None,
                'details': json.dumps(row.to_dict())
            })
        
        df = pd.DataFrame(events).sort_values('timestamp')
        df.to_csv(output_path, index=False)

# Usage example
analyzer = RecordingAnalyzer("~/Recordings/user_test_session")
patterns = analyzer.analyze_click_patterns()
analyzer.generate_heatmap()
analyzer.export_for_ux_analysis()
```

#### R Analysis Example
```r
# R script for statistical analysis of interaction data
library(jsonlite)
library(dplyr)
library(ggplot2)
library(lubridate)

# Load recording data
load_recording_data <- function(session_path) {
  mouse_file <- file.path(session_path, "input_data", "mouse_events.json")
  keyboard_file <- file.path(session_path, "input_data", "keyboard_events.json")
  
  mouse_data <- fromJSON(mouse_file)$mouse_events
  keyboard_data <- fromJSON(keyboard_file)$keyboard_events
  
  list(mouse = mouse_data, keyboard = keyboard_data)
}

# Analyze user efficiency metrics
analyze_efficiency <- function(data) {
  mouse_df <- data$mouse %>%
    mutate(timestamp = as_datetime(timestamp)) %>%
    arrange(timestamp)
  
  # Calculate movement efficiency (distance vs. time)
  mouse_df <- mouse_df %>%
    mutate(
      distance = sqrt((x - lag(x))^2 + (y - lag(y))^2),
      time_diff = as.numeric(timestamp - lag(timestamp))
    ) %>%
    filter(!is.na(distance), time_diff > 0)
  
  # Movement efficiency metrics
  total_distance <- sum(mouse_df$distance, na.rm = TRUE)
  total_time <- max(mouse_df$timestamp) - min(mouse_df$timestamp)
  avg_speed <- total_distance / as.numeric(total_time)
  
  list(
    total_distance = total_distance,
    total_time = total_time,
    average_speed = avg_speed,
    movement_efficiency = total_distance / as.numeric(total_time)
  )
}
```

### Machine Learning Integration

#### Gesture Recognition Model
```python
"""
Train a gesture recognition model from Did You Get It input data.
"""

import tensorflow as tf
from sklearn.model_selection import train_test_split
import numpy as np

class GestureRecognizer:
    def __init__(self):
        self.model = self.build_model()
        self.sequence_length = 50  # 50 events per sequence
        
    def build_model(self):
        """Build LSTM model for gesture recognition."""
        model = tf.keras.Sequential([
            tf.keras.layers.LSTM(128, return_sequences=True, input_shape=(50, 4)),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.LSTM(64, return_sequences=False),
            tf.keras.layers.Dropout(0.2),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dense(10, activation='softmax')  # 10 gesture classes
        ])
        
        model.compile(
            optimizer='adam',
            loss='categorical_crossentropy',
            metrics=['accuracy']
        )
        
        return model
    
    def preprocess_recording(self, session_path):
        """Convert recording data to model input format."""
        with open(f"{session_path}/input_data/mouse_events.json") as f:
            mouse_data = json.load(f)['mouse_events']
        
        # Extract features: x, y, timestamp, event_type_encoded
        sequences = []
        for i in range(len(mouse_data) - self.sequence_length + 1):
            sequence = []
            for j in range(i, i + self.sequence_length):
                event = mouse_data[j]
                features = [
                    event['x'] / 1920.0,  # Normalize coordinates
                    event['y'] / 1080.0,
                    event['timestamp'],
                    1.0 if event['type'] == 'click' else 0.0
                ]
                sequence.append(features)
            sequences.append(sequence)
        
        return np.array(sequences)
    
    def train(self, training_sessions, labels):
        """Train the model on multiple recording sessions."""
        X = []
        y = []
        
        for session_path, label in zip(training_sessions, labels):
            sequences = self.preprocess_recording(session_path)
            X.extend(sequences)
            y.extend([label] * len(sequences))
        
        X = np.array(X)
        y = tf.keras.utils.to_categorical(y, 10)
        
        X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2)
        
        self.model.fit(
            X_train, y_train,
            validation_data=(X_val, y_val),
            epochs=50,
            batch_size=32
        )
```

## Workflow Automation Examples

### Testing Workflow Automation
```bash
#!/bin/bash
# automated_testing.sh - Complete testing workflow with recording

set -e

PROJECT_DIR="$1"
TEST_SUITE="$2"
RECORDING_NAME="test_$(date +%Y%m%d_%H%M%S)"

echo "Starting automated testing workflow..."

# Setup recording environment
dygi config set --profile=testing \
    --frame-rate=30 \
    --resolution=1080p \
    --audio=system \
    --mouse-precision=high \
    --keyboard-tracking=true

# Start recording
echo "Starting recording: $RECORDING_NAME"
dygi start --profile=testing --name="$RECORDING_NAME"

# Run the test suite
echo "Running test suite: $TEST_SUITE"
cd "$PROJECT_DIR"

case "$TEST_SUITE" in
    "ui")
        npm run test:ui || TEST_FAILED=true
        ;;
    "integration")
        python -m pytest tests/integration/ || TEST_FAILED=true
        ;;
    "manual")
        echo "Perform manual testing now. Press Enter when complete."
        read -r
        ;;
    *)
        echo "Unknown test suite: $TEST_SUITE"
        exit 1
        ;;
esac

# Stop recording
echo "Stopping recording..."
RECORDING_FILES=$(dygi stop --json | jq -r '.files[]')

# Process results
if [ "$TEST_FAILED" = true ]; then
    echo "Tests failed. Processing recording for analysis..."
    
    # Extract failure screenshots
    dygi extract-frames \
        --video="$RECORDING_FILES" \
        --interval=1 \
        --output="screenshots/"
    
    # Generate interaction report
    python3 scripts/analyze_test_failure.py \
        --recording="$RECORDING_FILES" \
        --test-results="test_results.xml" \
        --output="failure_analysis.html"
    
    echo "Failure analysis complete. Check failure_analysis.html"
else
    echo "All tests passed!"
    
    # Archive successful recording for regression testing
    mkdir -p "test_baselines/"
    cp -r "$RECORDING_FILES" "test_baselines/"
fi
```

### Content Creation Pipeline
```python
#!/usr/bin/env python3
"""
Automated content creation pipeline using Did You Get It recordings.
"""

import subprocess
import json
import os
from pathlib import Path

class ContentCreationPipeline:
    def __init__(self, project_config):
        self.config = project_config
        self.session_name = f"content_{project_config['name']}"
        
    def record_demonstration(self):
        """Start recording with optimized settings for content creation."""
        cmd = [
            "dygi", "start",
            "--name", self.session_name,
            "--frame-rate", "60",
            "--resolution", "native",
            "--audio", "system,microphone",
            "--cursor", "highlight",
            "--area", self.config.get("recording_area", "screen")
        ]
        
        subprocess.run(cmd, check=True)
        print(f"Recording started: {self.session_name}")
        print("Perform your demonstration now...")
        
        # Wait for user to complete demonstration
        input("Press Enter when demonstration is complete...")
        
        # Stop recording and get file paths
        result = subprocess.run(
            ["dygi", "stop", "--json"],
            capture_output=True,
            text=True,
            check=True
        )
        
        return json.loads(result.stdout)
    
    def post_process_recording(self, recording_data):
        """Apply post-processing to enhance the recording."""
        video_file = recording_data["files"]["video"]
        
        # Generate thumbnail timeline
        subprocess.run([
            "ffmpeg", "-i", video_file,
            "-vf", "fps=1/10,scale=320:180",
            f"{self.session_name}_timeline_%03d.jpg"
        ], check=True)
        
        # Create chapters from input data
        self.create_chapters(recording_data["files"]["mouse_events"])
        
        # Generate captions from audio
        if "audio" in recording_data["files"]:
            self.generate_captions(recording_data["files"]["audio"])
    
    def create_chapters(self, mouse_events_file):
        """Create video chapters based on interaction patterns."""
        with open(mouse_events_file) as f:
            events = json.load(f)
        
        # Identify chapter breaks (periods of inactivity)
        chapters = []
        last_event_time = 0
        chapter_start = 0
        
        for event in events["mouse_events"]:
            if event["timestamp"] - last_event_time > 3:  # 3 seconds gap
                if last_event_time > 0:
                    chapters.append({
                        "start": chapter_start,
                        "end": last_event_time,
                        "title": f"Chapter {len(chapters) + 1}"
                    })
                chapter_start = event["timestamp"]
            last_event_time = event["timestamp"]
        
        # Save chapters file
        with open(f"{self.session_name}_chapters.json", "w") as f:
            json.dump(chapters, f, indent=2)

# Usage
config = {
    "name": "app_tutorial",
    "recording_area": "application:Xcode"
}

pipeline = ContentCreationPipeline(config)
recording_data = pipeline.record_demonstration()
pipeline.post_process_recording(recording_data)
```

Ready to troubleshoot issues? Continue to [Troubleshooting](troubleshooting.md) for comprehensive problem-solving guidance.