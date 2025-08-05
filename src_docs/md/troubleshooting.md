# 8. Troubleshooting

## Common Issues and Solutions

### Installation and Setup Issues

#### Application Won't Launch
**Problem:** "Did You Get It" cannot be opened because the developer cannot be verified.

**Solution:**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine "/Applications/Did You Get It.app"

# Or allow in System Preferences
# System Preferences → Security & Privacy → General → Allow "Did You Get It"
# Click "Open Anyway" if prompted
```

**Problem:** App crashes immediately on launch with error in Console.

**Diagnostic Steps:**
```bash
# Check system logs
log show --predicate 'process == "Did You Get It"' --last 10m

# Check crash reports
ls ~/Library/Logs/DiagnosticReports/Did\ You\ Get\ It*

# Verify app integrity
codesign -v "/Applications/Did You Get It.app"
```

**Common Causes and Fixes:**
- **Corrupted download**: Re-download from official source
- **Insufficient macOS version**: Requires macOS 13.0+
- **Missing dependencies**: Reinstall app or system updates
- **Conflicting software**: Disable other screen recording apps

#### Permission Issues
**Problem:** Recording fails with permission errors.

**Complete Permission Setup:**
```bash
# Check current permissions
tccutil list | grep "Did You Get It"

# Reset permissions (requires restart)
tccutil reset ScreenCapture it.didyouget.mac
tccutil reset Microphone it.didyouget.mac
tccutil reset Accessibility it.didyouget.mac

# Manual permission grant via System Preferences:
# 1. System Preferences → Security & Privacy → Privacy
# 2. Screen Recording → Check "Did You Get It"
# 3. Microphone → Check "Did You Get It" (if using audio)
# 4. Accessibility → Check "Did You Get It" (for input tracking)
```

**Permission Troubleshooting Script:**
```bash
#!/bin/bash
# permission_check.sh

echo "Checking Did You Get It permissions..."

# Check screen recording permission
if tccutil list | grep -q "kTCCServiceScreenCapture.*Did You Get It.*ALLOWED"; then
    echo "✅ Screen Recording: GRANTED"
else
    echo "❌ Screen Recording: DENIED - Please enable in System Preferences"
fi

# Check microphone permission
if tccutil list | grep -q "kTCCServiceMicrophone.*Did You Get It.*ALLOWED"; then
    echo "✅ Microphone: GRANTED"
else
    echo "⚠️  Microphone: DENIED - Enable if you need audio recording"
fi

# Check accessibility permission
if tccutil list | grep -q "kTCCServiceAccessibility.*Did You Get It.*ALLOWED"; then
    echo "✅ Accessibility: GRANTED"
else
    echo "❌ Accessibility: DENIED - Required for input tracking"
fi
```

### Recording Quality Issues

#### Poor Video Quality or Stuttering
**Problem:** Video appears pixelated, stuttering, or dropping frames.

**Diagnostic Information:**
```swift
// Check recording metrics in debug mode
struct RecordingDiagnostics {
    let actualFrameRate: Double
    let targetFrameRate: Int
    let droppedFrames: Int
    let memoryUsage: UInt64
    let cpuUsage: Double
    let diskWriteSpeed: Double
}
```

**Performance Optimization Steps:**

1. **Lower Recording Settings:**
```bash
# Reduce frame rate
dygi config set --frame-rate=30

# Lower resolution
dygi config set --resolution=1080p

# Disable unnecessary features
dygi config set --mouse-precision=low --audio=false
```

2. **System Optimization:**
```bash
# Close unnecessary applications
killall "Chrome" "Slack" "Discord"

# Check available disk space (need >5GB free)
df -h

# Monitor system resources
top -o cpu -l 3 | grep "Did You Get It"
```

3. **Hardware Recommendations:**
- **Minimum**: 8GB RAM, Intel i5 or Apple M1
- **Recommended**: 16GB RAM, Apple M1 Pro/Max or Intel i7
- **Storage**: SSD with >10GB free space

#### Audio Sync Issues
**Problem:** Audio and video are out of sync in recordings.

**Audio Sync Troubleshooting:**
```swift
// Debug audio-video synchronization
class AudioVideoSyncDiagnostic {
    func checkSyncOffset() {
        let videoTimestamp = videoProcessor.lastFrameTimestamp
        let audioTimestamp = audioProcessor.lastSampleTimestamp
        let offset = abs(videoTimestamp - audioTimestamp)
        
        if offset > 0.1 { // >100ms offset
            Logger.audio.warning("Sync offset detected: \(offset)s")
        }
    }
}
```

**Solutions:**
1. **Use system audio only** (most reliable sync)
2. **Check audio device sample rates** (ensure 48kHz)
3. **Close other audio applications**
4. **Restart Core Audio:**
```bash
sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod
```

### Input Tracking Problems

#### Mouse/Keyboard Events Not Recorded
**Problem:** Input tracking data files are empty or incomplete.

**Input Tracking Diagnostic:**
```swift
class InputTrackingDiagnostic {
    func diagnoseInputTracking() {
        // Check if accessibility permission is granted
        let trusted = AXIsProcessTrusted()
        print("Accessibility trusted: \(trusted)")
        
        // Test event monitoring
        let monitor = NSEvent.addGlobalMonitorForEventsMatching([.mouseMoved]) { event in
            print("Mouse event detected: \(event.locationInWindow)")
        }
        
        if monitor == nil {
            print("❌ Failed to create event monitor")
        }
    }
}
```

**Troubleshooting Steps:**
1. **Check Accessibility Permission:** System Preferences → Security & Privacy → Accessibility
2. **Restart the application** after granting permissions
3. **Test with simple movements:** Move mouse slowly and check if events are captured
4. **Check for interfering software:** Disable other input monitoring tools

#### Inaccurate Mouse Coordinates
**Problem:** Mouse coordinates don't match actual screen positions.

**Coordinate System Issues:**
```swift
// Debug coordinate transformations
func debugCoordinateSystem() {
    let screenFrame = NSScreen.main?.frame ?? .zero
    let mouseLocation = NSEvent.mouseLocation
    
    print("Screen frame: \(screenFrame)")
    print("Mouse location: \(mouseLocation)")
    print("Flipped Y: \(screenFrame.height - mouseLocation.y)")
}
```

**Common Causes:**
- **Multiple displays** with different scaling factors
- **Retina scaling** not accounted for
- **Coordinate system flipping** (macOS uses bottom-left origin)

**Fix:**
```swift
// Correct coordinate transformation
func correctMouseCoordinates(_ location: NSPoint) -> NSPoint {
    guard let screen = NSScreen.main else { return location }
    
    // Account for Retina scaling
    let scaleFactor = screen.backingScaleFactor
    let correctedX = location.x * scaleFactor
    
    // Flip Y coordinate (macOS uses bottom-left origin)
    let correctedY = (screen.frame.height - location.y) * scaleFactor
    
    return NSPoint(x: correctedX, y: correctedY)
}
```

### Performance and Resource Issues

#### High CPU Usage
**Problem:** "Did You Get It" consumes excessive CPU resources.

**CPU Usage Analysis:**
```bash
# Monitor CPU usage by thread
top -pid $(pgrep "Did You Get It") -l 5

# Detailed process analysis
sample "Did You Get It" 10 -f ~/Desktop/cpu_sample.txt

# Check for runaway threads
spindump "Did You Get It" -o ~/Desktop/spindump.txt
```

**CPU Optimization:**
```swift
// Implement frame rate throttling
class PerformanceManager {
    private let cpuThreshold: Double = 0.7
    
    func adjustSettingsForPerformance() {
        let currentCPU = getCurrentCPUUsage()
        
        if currentCPU > cpuThreshold {
            // Reduce frame rate
            recordingSettings.frameRate = max(24, recordingSettings.frameRate - 10)
            
            // Lower input tracking frequency
            inputSettings.samplingRate = max(30, inputSettings.samplingRate / 2)
            
            Logger.performance.info("Reduced settings due to high CPU usage: \(currentCPU)")
        }
    }
}
```

#### Memory Leaks
**Problem:** Memory usage continuously increases during recording.

**Memory Diagnostic Tools:**
```bash
# Monitor memory usage
memory_pressure

# Detailed memory analysis with Xcode Instruments
# Or use built-in diagnostic
leaks "Did You Get It"

# Check for excessive buffer allocation
vmmap $(pgrep "Did You Get It") | grep "MALLOC"
```

**Memory Leak Prevention:**
```swift
// Proper buffer management
class FrameBufferManager {
    private var bufferPool: [CVPixelBuffer] = []
    private let maxBuffers = 10
    
    func acquireBuffer() -> CVPixelBuffer? {
        defer { cleanupOldBuffers() }
        
        if let buffer = bufferPool.popLast() {
            return buffer
        }
        
        return createNewBuffer()
    }
    
    func returnBuffer(_ buffer: CVPixelBuffer) {
        guard bufferPool.count < maxBuffers else { return }
        bufferPool.append(buffer)
    }
    
    private func cleanupOldBuffers() {
        // Prevent excessive buffer accumulation
        while bufferPool.count > maxBuffers {
            bufferPool.removeFirst()
        }
    }
}
```

### File and Export Issues

#### Recording Files Corrupted or Unplayable
**Problem:** Output video files won't play or appear corrupted.

**File Integrity Check:**
```bash
# Check video file integrity
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,duration recording.mov

# Verify file wasn't truncated
ls -la recording.mov
file recording.mov

# Test playback with different players
quicktime-player recording.mov
vlc recording.mov
ffplay recording.mov
```

**Recovery Options:**
```bash
# Attempt file repair with FFmpeg
ffmpeg -i corrupted_recording.mov -c copy -avoid_negative_ts make_zero repaired_recording.mov

# Extract usable frames from partial file
ffmpeg -i partial_recording.mov -r 1 frame_%04d.png

# Recover audio track separately
ffmpeg -i recording.mov -vn -acodec copy audio_track.wav
```

#### Large File Sizes
**Problem:** Recording files are unexpectedly large.

**File Size Analysis:**
```bash
# Analyze video properties
ffprobe -v quiet -print_format json -show_streams recording.mov | jq '.streams[]'

# Calculate expected file size
# Formula: (width × height × fps × duration × bit_depth) / 8 / compression_ratio
```

**Size Optimization:**
```bash
# Post-recording compression
ffmpeg -i large_recording.mov \
    -c:v libx264 \
    -crf 23 \
    -preset medium \
    -c:a aac \
    -b:a 128k \
    optimized_recording.mp4

# Reduce resolution while maintaining quality
ffmpeg -i recording.mov \
    -vf scale=1920:1080 \
    -c:v libx264 \
    -crf 20 \
    scaled_recording.mp4
```

## Advanced Diagnostics

### System Compatibility Check

#### Compatibility Diagnostic Script
```bash
#!/bin/bash
# system_compatibility.sh

echo "=== Did You Get It System Compatibility Check ==="

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "macOS Version: $MACOS_VERSION"

if [[ $(echo "$MACOS_VERSION >= 13.0" | bc -l) -eq 1 ]]; then
    echo "✅ macOS version compatible"
else
    echo "❌ macOS 13.0+ required"
fi

# Check hardware
HARDWARE=$(system_profiler SPHardwareDataType | grep "Model Name" | cut -d: -f2 | xargs)
echo "Hardware: $HARDWARE"

# Check available RAM
RAM_GB=$(system_profiler SPHardwareDataType | grep "Memory:" | awk '{print $2}')
echo "RAM: ${RAM_GB}GB"

if [[ ${RAM_GB%.*} -ge 8 ]]; then
    echo "✅ Sufficient RAM"
else
    echo "⚠️  8GB+ RAM recommended"
fi

# Check disk space
DISK_SPACE=$(df -h / | awk 'NR==2{print $4}')
echo "Available Disk Space: $DISK_SPACE"

# Check ScreenCaptureKit availability
if [[ $(echo "$MACOS_VERSION >= 12.3" | bc -l) -eq 1 ]]; then
    echo "✅ ScreenCaptureKit available"
else
    echo "❌ ScreenCaptureKit requires macOS 12.3+"
fi
```

### Network and Firewall Issues

#### Network Diagnostic (for CLI/API features)
```bash
# Check if CLI service is running
lsof -i :8080 | grep "Did You Get It"

# Test local API connectivity
curl -s http://localhost:8080/api/status

# Check firewall rules
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### Debug Logging

#### Enable Verbose Logging
```swift
// Enable debug logging in preferences
struct DebugSettings {
    static var verboseLogging = false
    static var logLevel: LogLevel = .info
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO" 
        case warning = "WARNING"
        case error = "ERROR"
    }
}

// Usage in application
Logger.recording.debug("Frame processed: \(frameNumber), timestamp: \(timestamp)")
```

#### Access Debug Logs
```bash
# Application logs location
tail -f ~/Library/Logs/DidYouGetIt/application.log

# System logs
log show --predicate 'subsystem == "it.didyouget.mac"' --last 1h

# Export logs for support
log collect --start '2024-01-15 14:00:00' --output ~/Desktop/didyougetit_logs.logarchive
```

## Getting Help and Support

### Information to Gather Before Reporting Issues

#### System Information Script
```bash
#!/bin/bash
# gather_system_info.sh

echo "=== Did You Get It Support Information ==="
echo "Generated: $(date)"
echo

echo "System Information:"
sw_vers
echo

echo "Hardware:"
system_profiler SPHardwareDataType | grep -E "(Model Name|Processor|Memory|Graphics)"
echo

echo "Permissions:"
tccutil list | grep "Did You Get It"
echo

echo "Recent Crashes:"
ls -la ~/Library/Logs/DiagnosticReports/Did\ You\ Get\ It* 2>/dev/null | tail -5
echo

echo "Disk Space:"
df -h /
echo

echo "Running Processes:"
ps aux | grep -i "did you get it\|screen.*record\|capture"
```

#### Bug Report Template
When reporting issues, please include:

1. **System Information:**
   - macOS version
   - Hardware model
   - Available RAM and disk space

2. **Application Information:**
   - Did You Get It version
   - Installation method (direct download, build from source)
   - Configuration settings used

3. **Problem Description:**
   - What you were trying to do
   - What happened instead
   - Steps to reproduce
   - Frequency of occurrence

4. **Logs and Diagnostics:**
   ```bash
   # Gather comprehensive diagnostic info
   ./gather_system_info.sh > support_info.txt
   
   # Include recent logs
   tail -100 ~/Library/Logs/DidYouGetIt/application.log >> support_info.txt
   ```

### Community Resources

#### GitHub Repository
- **Issues**: https://github.com/twardoch/didyougetit-mac/issues
- **Discussions**: https://github.com/twardoch/didyougetit-mac/discussions
- **Wiki**: https://github.com/twardoch/didyougetit-mac/wiki

#### Documentation Resources
- **FAQ**: Check the FAQ section for common questions
- **Video Tutorials**: Step-by-step video guides
- **Community Examples**: User-contributed scripts and workflows

### Performance Tuning Guide

#### Optimization Checklist
```bash
# Quick performance optimization
echo "Running performance optimization..."

# 1. Close unnecessary applications
osascript -e 'tell application "Chrome" to quit'
osascript -e 'tell application "Slack" to quit'

# 2. Free up RAM
sudo purge

# 3. Check and optimize recording settings
dygi config optimize --for-performance

# 4. Clean up temporary files
rm -rf ~/Library/Caches/it.didyouget.mac/temp/*

# 5. Restart Core Audio (if audio issues)
sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod

echo "Performance optimization complete!"
```

Ready to contribute to development? Continue to [Development & Contributing](development.md) for technical details and contribution guidelines.