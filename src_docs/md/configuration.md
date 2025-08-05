# 6. Configuration & Settings

## Settings Architecture

### Preferences Storage System

#### UserDefaults Integration
Did You Get It uses a sophisticated preferences system built on UserDefaults with type safety and validation:

```swift
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

class PreferencesManager: ObservableObject {
    // Video settings
    @UserDefault(key: "recording.frameRate", defaultValue: 60)
    @Published var frameRate: Int
    
    @UserDefault(key: "recording.resolution", defaultValue: "native")
    @Published var resolution: String
    
    @UserDefault(key: "recording.showCursor", defaultValue: true)
    @Published var showCursor: Bool
    
    // Audio settings
    @UserDefault(key: "audio.systemEnabled", defaultValue: true)
    @Published var systemAudioEnabled: Bool
    
    @UserDefault(key: "audio.microphoneEnabled", defaultValue: false)
    @Published var microphoneEnabled: Bool
}
```

#### Configuration Validation
```swift
protocol ConfigurationValidator {
    func validate(_ configuration: RecordingConfiguration) throws
}

struct RecordingConfigurationValidator: ConfigurationValidator {
    func validate(_ configuration: RecordingConfiguration) throws {
        // Validate video settings
        guard configuration.frameRate > 0 && configuration.frameRate <= 120 else {
            throw ValidationError.invalidFrameRate(configuration.frameRate)
        }
        
        // Validate recording area
        guard configuration.recordingArea.width > 0 && configuration.recordingArea.height > 0 else {
            throw ValidationError.invalidRecordingArea
        }
        
        // Validate output location
        guard FileManager.default.isWritableFile(atPath: configuration.outputLocation.path) else {
            throw ValidationError.inaccessibleOutputLocation(configuration.outputLocation)
        }
    }
}
```

## Video Recording Settings

### Frame Rate Configuration

#### Available Frame Rates
```swift
enum FrameRate: Int, CaseIterable, Identifiable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .fps24: return "24 FPS (Cinematic)"
        case .fps30: return "30 FPS (Standard)"
        case .fps60: return "60 FPS (Smooth)"
        case .fps120: return "120 FPS (Ultra Smooth)"
        }
    }
    
    var recommendedFor: String {
        switch self {
        case .fps24: return "Film-like content, long recordings"
        case .fps30: return "General tutorials, presentations"
        case .fps60: return "Smooth UI demonstrations"
        case .fps120: return "High-motion content, gaming"
        }
    }
}
```

#### Dynamic Frame Rate Adjustment
```swift
class AdaptiveFrameRateManager {
    private var targetFrameRate: Int
    private var currentFrameRate: Int = 0
    private let performanceMonitor: PerformanceMonitor
    
    func adjustFrameRateIfNeeded() {
        let systemLoad = performanceMonitor.cpuUsage
        let memoryPressure = performanceMonitor.memoryPressure
        
        if systemLoad > 0.8 || memoryPressure > 0.9 {
            // Reduce frame rate to maintain system performance
            let adjustedRate = max(24, targetFrameRate / 2)
            updateFrameRate(to: adjustedRate)
        }
    }
}
```

### Resolution Settings

#### Resolution Presets
```swift
enum Resolution: String, CaseIterable {
    case native = "native"
    case retina2x = "retina2x"
    case fullHD = "1080p"
    case quadHD = "1440p"
    case ultraHD = "4k"
    case custom = "custom"
    
    var dimensions: (width: Int, height: Int) {
        switch self {
        case .native:
            return getCurrentDisplayResolution()
        case .retina2x:
            let native = getCurrentDisplayResolution()
            return (native.width / 2, native.height / 2)
        case .fullHD:
            return (1920, 1080)
        case .quadHD:
            return (2560, 1440)
        case .ultraHD:
            return (3840, 2160)
        case .custom:
            return getCustomResolution()
        }
    }
}
```

#### Custom Resolution Configuration
```swift
struct CustomResolution {
    var width: Int
    var height: Int
    
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }
    
    var isValid: Bool {
        return width >= 320 && height >= 240 && width <= 7680 && height <= 4320
    }
    
    static let commonAspectRatios: [(ratio: Double, name: String)] = [
        (16.0/9.0, "16:9 Widescreen"),
        (4.0/3.0, "4:3 Standard"),
        (21.0/9.0, "21:9 Ultrawide"),
        (1.0, "1:1 Square")
    ]
}
```

### Quality and Compression Settings

#### Video Quality Presets
```swift
enum VideoQuality: String, CaseIterable {
    case maximum = "maximum"
    case high = "high"
    case medium = "medium"
    case low = "low"
    case custom = "custom"
    
    var bitRateMultiplier: Double {
        switch self {
        case .maximum: return 1.0
        case .high: return 0.8
        case .medium: return 0.6
        case .low: return 0.4
        case .custom: return 1.0 // User-defined
        }
    }
    
    var compressionSettings: VideoCompressionSettings {
        VideoCompressionSettings(
            codec: .h264,
            bitRate: baseBitRate * bitRateMultiplier,
            keyFrameInterval: keyFrameInterval,
            profile: profile
        )
    }
}
```

## Audio Recording Settings

### Audio Source Configuration

#### System Audio Settings
```swift
struct SystemAudioSettings {
    var enabled: Bool = true
    var includeSystemSounds: Bool = true
    var excludeApplications: [String] = []
    var outputFormat: AudioFormat = .aac
    var sampleRate: AudioSampleRate = .rate48kHz
    var bitDepth: AudioBitDepth = .depth24bit
    
    enum AudioFormat: String, CaseIterable {
        case aac = "AAC"
        case mp3 = "MP3"
        case wav = "WAV"
        case flac = "FLAC"
        
        var fileExtension: String {
            return rawValue.lowercased()
        }
    }
}
```

#### Microphone Configuration
```swift
struct MicrophoneSettings {
    var enabled: Bool = false
    var deviceID: String = "default"
    var inputGain: Float = 1.0
    var noiseReduction: Bool = true
    var autoGainControl: Bool = false
    var monitoringEnabled: Bool = false
    
    var inputLevelThreshold: Float = 0.01 // Silence threshold
    var maxInputLevel: Float = 1.0
    
    func validateSettings() throws {
        guard inputGain >= 0.1 && inputGain <= 2.0 else {
            throw AudioError.invalidInputGain(inputGain)
        }
        
        guard AudioDeviceManager.shared.isDeviceAvailable(deviceID) else {
            throw AudioError.deviceNotAvailable(deviceID)
        }
    }
}
```

#### Audio Device Management
```swift
class AudioDeviceManager: ObservableObject {
    static let shared = AudioDeviceManager()
    
    @Published var availableInputDevices: [AudioDevice] = []
    @Published var availableOutputDevices: [AudioDevice] = []
    
    struct AudioDevice: Identifiable, Codable {
        let id: String
        let name: String
        let type: DeviceType
        let sampleRates: [Double]
        let channelCount: Int
        
        enum DeviceType: String, Codable {
            case builtin = "Built-in"
            case usb = "USB"
            case bluetooth = "Bluetooth"
            case aggregate = "Aggregate"
        }
    }
    
    func refreshDevices() {
        // Enumerate available audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get device list from Core Audio
        // Implementation details...
    }
}
```

### Audio Processing Settings

#### Real-Time Audio Effects
```swift
struct AudioProcessingSettings {
    var noiseReduction: NoiseReductionSettings = .standard
    var dynamicsProcessing: DynamicsSettings = .disabled
    var equalization: EqualizationSettings = .flat
    
    struct NoiseReductionSettings {
        var enabled: Bool = true
        var strength: Float = 0.5 // 0.0 to 1.0
        var spectralGating: Bool = true
        
        static let standard = NoiseReductionSettings()
        static let aggressive = NoiseReductionSettings(enabled: true, strength: 0.8, spectralGating: true)
        static let disabled = NoiseReductionSettings(enabled: false, strength: 0.0, spectralGating: false)
    }
    
    struct DynamicsSettings {
        var compressor: CompressorSettings = .disabled
        var limiter: LimiterSettings = .standard
        
        static let disabled = DynamicsSettings()
    }
}
```

## Input Tracking Settings

### Mouse Tracking Configuration

#### Precision and Filtering Settings
```swift
struct MouseTrackingSettings {
    var enabled: Bool = true
    var precision: TrackingPrecision = .standard
    var captureClicks: Bool = true
    var captureDrags: Bool = true
    var captureScrolling: Bool = true
    var minimumMovementThreshold: Double = 1.0 // pixels
    
    enum TrackingPrecision: String, CaseIterable {
        case low = "Low (integer pixels)"
        case standard = "Standard (pixel precision)"
        case high = "High (sub-pixel precision)"
        
        var samplingRate: Double {
            switch self {
            case .low: return 30.0    // 30 Hz
            case .standard: return 60.0   // 60 Hz
            case .high: return 120.0  // 120 Hz
            }
        }
        
        var coordinatePrecision: Int {
            switch self {
            case .low: return 0       // Integer pixels
            case .standard: return 1  // 0.1 pixel precision
            case .high: return 2      // 0.01 pixel precision
            }
        }
    }
}
```

#### Click Detection Settings
```swift
struct ClickDetectionSettings {
    var detectSingleClicks: Bool = true
    var detectDoubleClicks: Bool = true
    var detectRightClicks: Bool = true
    var detectMiddleClicks: Bool = true
    var captureClickDuration: Bool = true
    
    var doubleClickTimeThreshold: TimeInterval = 0.5
    var longClickTimeThreshold: TimeInterval = 0.5
    
    // Click pressure sensitivity (for pressure-sensitive devices)
    var pressureSensitivity: Float = 0.5
    var capturePressureData: Bool = false
}
```

### Keyboard Tracking Configuration

#### Key Capture Settings
```swift
struct KeyboardTrackingSettings {
    var enabled: Bool = true
    var captureMode: CaptureMode = .keysOnly
    var captureModifierKeys: Bool = true
    var captureKeyRepeat: Bool = false
    var minimumKeyPressDuration: TimeInterval = 0.05
    
    enum CaptureMode: String, CaseIterable {
        case keysOnly = "Key codes only"
        case characters = "Characters typed"
        case both = "Keys and characters"
        
        var capturesKeyCode: Bool {
            return self == .keysOnly || self == .both
        }
        
        var capturesCharacters: Bool {
            return self == .characters || self == .both
        }
    }
    
    // Privacy settings
    var excludeSecureFields: Bool = true
    var excludePasswordFields: Bool = true
    var anonymizeText: Bool = false
}
```

#### Privacy and Security Configuration
```swift
struct PrivacySettings {
    var respectSecureInput: Bool = true
    var excludeApplications: [String] = [
        "com.apple.keychainaccess",
        "com.apple.securityagent",
        "com.apple.systempreferences"
    ]
    
    var dataRetentionPolicy: DataRetentionPolicy = .sessionOnly
    var encryptSensitiveData: Bool = false
    
    enum DataRetentionPolicy: String, CaseIterable {
        case sessionOnly = "Delete after session"
        case temporary = "Delete after 24 hours"
        case permanent = "Keep until manually deleted"
    }
}
```

## Output and File Settings

### File Naming and Organization

#### Naming Templates
```swift
struct FileNamingSettings {
    var template: String = "recording_{date}_{time}"
    var dateFormat: String = "yyyy-MM-dd"
    var timeFormat: String = "HH-mm-ss"
    var includeSequenceNumber: Bool = false
    var customPrefix: String = ""
    var customSuffix: String = ""
    
    // Available template variables
    static let availableVariables = [
        "{date}": "Current date",
        "{time}": "Current time",
        "{duration}": "Recording duration",
        "{resolution}": "Recording resolution",
        "{fps}": "Frame rate",
        "{display}": "Display name"
    ]
    
    func generateFileName(for session: RecordingSession) -> String {
        var fileName = template
        let dateFormatter = DateFormatter()
        
        // Replace template variables
        dateFormatter.dateFormat = dateFormat
        fileName = fileName.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: session.startTime))
        
        dateFormatter.dateFormat = timeFormat
        fileName = fileName.replacingOccurrences(of: "{time}", with: dateFormatter.string(from: session.startTime))
        
        // Add prefix and suffix
        if !customPrefix.isEmpty {
            fileName = customPrefix + fileName
        }
        
        if !customSuffix.isEmpty {
            fileName = fileName + customSuffix
        }
        
        return fileName
    }
}
```

#### Directory Structure Settings
```swift
struct DirectorySettings {
    var baseOutputLocation: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    var createSessionDirectories: Bool = true
    var organizeByDate: Bool = false
    var organizationStructure: OrganizationStructure = .flat
    
    enum OrganizationStructure: String, CaseIterable {
        case flat = "All files in one directory"
        case byType = "Separate folders for video/audio/data"
        case byDate = "Organize by recording date"
        case byProject = "Organize by project/tag"
        
        func createDirectoryStructure(at baseURL: URL, for session: RecordingSession) throws -> URL {
            switch self {
            case .flat:
                return baseURL
            case .byType:
                try createTypeBasedStructure(at: baseURL)
                return baseURL
            case .byDate:
                return try createDateBasedStructure(at: baseURL, for: session.startTime)
            case .byProject:
                return try createProjectBasedStructure(at: baseURL, project: session.projectName)
            }
        }
    }
}
```

### Export Settings

#### Multi-Format Export
```swift
struct ExportSettings {
    var videoFormats: [VideoExportFormat] = [.mov]
    var audioFormats: [AudioExportFormat] = [.wav]
    var dataFormats: [DataExportFormat] = [.json]
    var createMasterFile: Bool = true
    
    enum VideoExportFormat: String, CaseIterable {
        case mov = "MOV (QuickTime)"
        case mp4 = "MP4 (MPEG-4)"
        case avi = "AVI (Audio Video Interleave)"
        case mkv = "MKV (Matroska)"
        
        var fileExtension: String {
            return String(rawValue.prefix(3).lowercased())
        }
        
        var codec: AVVideoCodecType {
            switch self {
            case .mov, .mp4: return .h264
            case .avi: return .h264
            case .mkv: return .hevc
            }
        }
    }
    
    enum DataExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case xml = "XML"
        case sqlite = "SQLite Database"
        
        var fileExtension: String {
            return rawValue.lowercased()
        }
    }
}
```

## Performance and Resource Settings

### System Resource Management

#### Performance Profiles
```swift
enum PerformanceProfile: String, CaseIterable {
    case battery = "Battery Saver"
    case balanced = "Balanced"
    case performance = "High Performance"
    case custom = "Custom"
    
    var settings: PerformanceSettings {
        switch self {
        case .battery:
            return PerformanceSettings(
                maxCPUUsage: 0.4,
                frameRate: 24,
                resolution: .retina2x,
                audioQuality: .medium
            )
        case .balanced:
            return PerformanceSettings(
                maxCPUUsage: 0.6,
                frameRate: 30,
                resolution: .native,
                audioQuality: .high
            )
        case .performance:
            return PerformanceSettings(
                maxCPUUsage: 0.8,
                frameRate: 60,
                resolution: .native,
                audioQuality: .maximum
            )
        case .custom:
            return PreferencesManager.shared.customPerformanceSettings
        }
    }
}
```

#### Resource Monitoring Settings
```swift
struct ResourceMonitoringSettings {
    var enableCPUThrottling: Bool = true
    var cpuThrottleThreshold: Double = 0.8
    var enableMemoryManagement: Bool = true
    var memoryWarningThreshold: UInt64 = 2_000_000_000 // 2GB
    var diskSpaceWarningThreshold: UInt64 = 5_000_000_000 // 5GB
    
    var enablePerformanceLogging: Bool = false
    var performanceLogInterval: TimeInterval = 5.0
}
```

## Advanced Configuration

### Command Line Interface Settings

#### CLI Configuration
```swift
struct CLISettings {
    var enableCLIAccess: Bool = false
    var cliPort: Int = 8080
    var requireAuthentication: Bool = true
    var allowRemoteAccess: Bool = false
    
    // Available CLI commands
    static let availableCommands = [
        "start": "Start recording with specified parameters",
        "stop": "Stop current recording",
        "status": "Get current recording status",
        "config": "View or modify configuration",
        "export": "Export recording in different formats"
    ]
}
```

#### Automation Integration
```swift
struct AutomationSettings {
    var enableAppleScript: Bool = true
    var enableShortcuts: Bool = true
    var enableURLScheme: Bool = true
    
    // URL scheme: didyougetit://record?area=screen&audio=system
    var urlSchemeActions: [String: AutomationAction] = [
        "record": .startRecording,
        "stop": .stopRecording,
        "pause": .pauseRecording,
        "config": .openConfiguration
    ]
}
```

Ready to explore power-user features? Continue to [Advanced Usage](advanced-usage.md) for automation, scripting, and integration options.