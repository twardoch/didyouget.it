//
//  Errors.swift
//  DidYouGet
//
//  Comprehensive error types for the application
//
// this_file: DidYouGet/DidYouGet/Utilities/Errors.swift

import Foundation

// MARK: - Video Errors

enum VideoError: LocalizedError {
    case invalidSettings(reason: String)
    case codecNotSupported(codec: String)
    case encodingFailed(underlying: Error)
    case writerNotReady
    case frameLimitExceeded(limit: Int)
    case bufferAllocationFailed
    case pixelBufferCreationFailed
    case formatDescriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidSettings(let reason):
            return "Invalid video settings: \(reason)"
        case .codecNotSupported(let codec):
            return "Video codec '\(codec)' is not supported on this system"
        case .encodingFailed(let error):
            return "Video encoding failed: \(error.localizedDescription)"
        case .writerNotReady:
            return "Video writer is not ready to accept frames"
        case .frameLimitExceeded(let limit):
            return "Frame limit exceeded (maximum: \(limit))"
        case .bufferAllocationFailed:
            return "Failed to allocate video buffer"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .formatDescriptionFailed:
            return "Failed to create video format description"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidSettings:
            return "Check your video quality settings and try again"
        case .codecNotSupported:
            return "Try using H.264 codec which is universally supported"
        case .encodingFailed:
            return "Try reducing video quality or frame rate"
        case .writerNotReady:
            return "Ensure recording has started before processing frames"
        case .frameLimitExceeded:
            return "Stop and save the current recording, then start a new one"
        case .bufferAllocationFailed, .pixelBufferCreationFailed:
            return "Free up system memory and try again"
        case .formatDescriptionFailed:
            return "Try using standard video dimensions (1920x1080)"
        }
    }
}

// MARK: - Audio Errors

enum AudioError: LocalizedError {
    case deviceNotFound(deviceName: String)
    case formatNotSupported(format: String)
    case processingFailed(underlying: Error)
    case bufferAllocationFailed
    case engineStartFailed
    case noInputAvailable
    case sampleRateMismatch(expected: Int, actual: Int)
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let name):
            return "Audio device '\(name)' not found"
        case .formatNotSupported(let format):
            return "Audio format '\(format)' is not supported"
        case .processingFailed(let error):
            return "Audio processing failed: \(error.localizedDescription)"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer"
        case .engineStartFailed:
            return "Failed to start audio engine"
        case .noInputAvailable:
            return "No audio input device available"
        case .sampleRateMismatch(let expected, let actual):
            return "Sample rate mismatch: expected \(expected)Hz, got \(actual)Hz"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .deviceNotFound:
            return "Connect an audio input device or select a different one"
        case .formatNotSupported:
            return "Use standard audio format (44.1kHz or 48kHz)"
        case .processingFailed:
            return "Check audio device connection and permissions"
        case .bufferAllocationFailed:
            return "Free up system memory and try again"
        case .engineStartFailed:
            return "Restart the application and try again"
        case .noInputAvailable:
            return "Connect a microphone or enable system audio"
        case .sampleRateMismatch:
            return "Configure audio device to match expected sample rate"
        }
    }
}

// MARK: - Capture Errors

enum CaptureError: LocalizedError {
    case notSupported(reason: String)
    case permissionDenied(permission: PermissionType)
    case invalidConfiguration(reason: String)
    case captureFailure(underlying: Error)
    case initializationFailed
    case displayNotFound(displayID: UInt32)
    case windowNotFound(windowID: UInt32)
    case streamCreationFailed
    case contentNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .notSupported(let reason):
            return "Screen capture not supported: \(reason)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission.rawValue)"
        case .invalidConfiguration(let reason):
            return "Invalid capture configuration: \(reason)"
        case .captureFailure(let error):
            return "Capture failed: \(error.localizedDescription)"
        case .initializationFailed:
            return "Failed to initialize capture session"
        case .displayNotFound(let id):
            return "Display with ID \(id) not found"
        case .windowNotFound(let id):
            return "Window with ID \(id) not found"
        case .streamCreationFailed:
            return "Failed to create capture stream"
        case .contentNotAvailable:
            return "No content available for capture"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notSupported:
            return "Update to macOS 12.3 or later"
        case .permissionDenied(let permission):
            return "Grant \(permission.rawValue) permission in System Settings > Privacy & Security"
        case .invalidConfiguration:
            return "Check capture settings and try again"
        case .captureFailure:
            return "Restart the application and try again"
        case .initializationFailed:
            return "Check system resources and permissions"
        case .displayNotFound:
            return "Select a different display or reconnect external monitor"
        case .windowNotFound:
            return "Select a different window or ensure the window is visible"
        case .streamCreationFailed:
            return "Close other recording applications and try again"
        case .contentNotAvailable:
            return "Ensure there is content to record on the selected display"
        }
    }
}

// MARK: - File Errors

enum FileError: LocalizedError {
    case directoryCreationFailed(path: String, underlying: Error)
    case fileWriteFailed(path: String, underlying: Error)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case invalidPath(path: String)
    case fileNotFound(path: String)
    case permissionDenied(path: String)
    case fileLocked(path: String)
    
    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let path, let error):
            return "Failed to create directory at '\(path)': \(error.localizedDescription)"
        case .fileWriteFailed(let path, let error):
            return "Failed to write file at '\(path)': \(error.localizedDescription)"
        case .insufficientDiskSpace(let required, let available):
            let formatter = ByteCountFormatter()
            let reqStr = formatter.string(fromByteCount: required)
            let availStr = formatter.string(fromByteCount: available)
            return "Insufficient disk space: \(reqStr) required, only \(availStr) available"
        case .invalidPath(let path):
            return "Invalid file path: '\(path)'"
        case .fileNotFound(let path):
            return "File not found: '\(path)'"
        case .permissionDenied(let path):
            return "Permission denied to access: '\(path)'"
        case .fileLocked(let path):
            return "File is locked: '\(path)'"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .directoryCreationFailed:
            return "Check folder permissions and available space"
        case .fileWriteFailed:
            return "Ensure the destination is writable and has space"
        case .insufficientDiskSpace:
            return "Free up disk space or choose a different location"
        case .invalidPath:
            return "Choose a valid save location"
        case .fileNotFound:
            return "Verify the file exists and path is correct"
        case .permissionDenied:
            return "Grant file access permission or choose a different location"
        case .fileLocked:
            return "Close any applications using this file"
        }
    }
}

// MARK: - State Errors

enum StateError: LocalizedError {
    case invalidState(current: String, expected: String)
    case stateTransitionFailed(from: String, to: String)
    case concurrentOperation(operation: String)
    case operationInProgress(operation: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidState(let current, let expected):
            return "Invalid state: current '\(current)', expected '\(expected)'"
        case .stateTransitionFailed(let from, let to):
            return "State transition failed: cannot go from '\(from)' to '\(to)'"
        case .concurrentOperation(let operation):
            return "Cannot perform '\(operation)': another operation is in progress"
        case .operationInProgress(let operation):
            return "Operation '\(operation)' is already in progress"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidState:
            return "Complete the current operation before starting a new one"
        case .stateTransitionFailed:
            return "Check the application state and try again"
        case .concurrentOperation:
            return "Wait for the current operation to complete"
        case .operationInProgress:
            return "Wait for the operation to complete or cancel it"
        }
    }
}

// MARK: - Configuration Errors

enum ConfigurationError: LocalizedError {
    case missingRequiredField(field: String)
    case invalidValue(field: String, value: String, reason: String)
    case incompatibleSettings(setting1: String, setting2: String)
    case unsupportedConfiguration(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: '\(field)'"
        case .invalidValue(let field, let value, let reason):
            return "Invalid value '\(value)' for field '\(field)': \(reason)"
        case .incompatibleSettings(let setting1, let setting2):
            return "Incompatible settings: '\(setting1)' and '\(setting2)'"
        case .unsupportedConfiguration(let reason):
            return "Unsupported configuration: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField:
            return "Provide all required configuration values"
        case .invalidValue:
            return "Use a valid value for this setting"
        case .incompatibleSettings:
            return "Adjust settings to be compatible"
        case .unsupportedConfiguration:
            return "Use a supported configuration"
        }
    }
}

// MARK: - Error Extensions

extension Error {
    /// Convert any error to a user-friendly message
    var userFriendlyMessage: String {
        if let localizedError = self as? LocalizedError {
            return localizedError.errorDescription ?? localizedError.localizedDescription
        }
        return localizedDescription
    }
    
    /// Get recovery suggestion if available
    var recoverySuggestion: String? {
        if let localizedError = self as? LocalizedError {
            return localizedError.recoverySuggestion
        }
        return nil
    }
    
    /// Log the error with appropriate category
    func log(category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.logError(self, category: category, file: file, function: function, line: line)
    }
}