//
//  RecordingManager+Singleton.swift
//  DidYouGet
//
//  Singleton implementation for RecordingManager
//
// this_file: DidYouGet/DidYouGet/Models/RecordingManager+Singleton.swift

import Foundation

@available(macOS 12.3, *)
extension RecordingManager {
    
    // MARK: - Singleton Implementation
    
    /// Thread-safe singleton instance
    @MainActor
    static let shared: RecordingManager = {
        let instance = RecordingManager()
        logInfo("RecordingManager singleton created", category: .recording)
        return instance
    }()
    
    /// Private initializer to enforce singleton pattern
    /// Note: This is commented out to maintain compatibility with existing code
    /// In a production app, we would make the init private and update all references
    /*
    private override init() {
        super.init()
    }
    */
    
    /// Prevent cloning
    @MainActor
    func copy() -> RecordingManager {
        logWarning("Attempted to copy RecordingManager singleton", category: .recording)
        return RecordingManager.shared
    }
}

// MARK: - Manager Registry

/// Central registry for all singleton managers
@MainActor
final class ManagerRegistry {
    
    // MARK: - Singleton
    
    static let shared = ManagerRegistry()
    
    // MARK: - Properties
    
    private var recordingManager: RecordingManager?
    private var preferencesManager: PreferencesManager?
    private var versionManager: VersionManager?
    
    // MARK: - Initialization
    
    private init() {
        logInfo("ManagerRegistry initialized", category: .general)
    }
    
    // MARK: - Registration
    
    func register(recordingManager: RecordingManager) {
        guard self.recordingManager == nil else {
            logWarning("Attempting to register RecordingManager when one already exists", category: .recording)
            return
        }
        self.recordingManager = recordingManager
        logInfo("RecordingManager registered", category: .recording)
    }
    
    func register(preferencesManager: PreferencesManager) {
        guard self.preferencesManager == nil else {
            logWarning("Attempting to register PreferencesManager when one already exists", category: .preferences)
            return
        }
        self.preferencesManager = preferencesManager
        logInfo("PreferencesManager registered", category: .preferences)
    }
    
    func register(versionManager: VersionManager) {
        guard self.versionManager == nil else {
            logWarning("Attempting to register VersionManager when one already exists", category: .general)
            return
        }
        self.versionManager = versionManager
        logInfo("VersionManager registered", category: .general)
    }
    
    // MARK: - Access
    
    func getRecordingManager() -> RecordingManager {
        if let manager = recordingManager {
            return manager
        } else {
            logWarning("RecordingManager not registered, returning shared instance", category: .recording)
            return RecordingManager.shared
        }
    }
    
    func getPreferencesManager() -> PreferencesManager {
        if let manager = preferencesManager {
            return manager
        } else {
            logWarning("PreferencesManager not registered, creating new instance", category: .preferences)
            let manager = PreferencesManager.shared
            register(preferencesManager: manager)
            return manager
        }
    }
    
    func getVersionManager() -> VersionManager {
        if let manager = versionManager {
            return manager
        } else {
            logWarning("VersionManager not registered, creating new instance", category: .general)
            let manager = VersionManager.shared
            register(versionManager: manager)
            return manager
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        logWarning("Resetting ManagerRegistry - all managers will be deregistered", category: .general)
        recordingManager = nil
        preferencesManager = nil
        versionManager = nil
    }
}

// MARK: - PreferencesManager Singleton

extension PreferencesManager {
    
    /// Thread-safe singleton instance
    @MainActor
    static let shared: PreferencesManager = {
        let instance = PreferencesManager()
        logInfo("PreferencesManager singleton created", category: .preferences)
        return instance
    }()
}

// MARK: - VersionManager Singleton

extension VersionManager {
    
    /// Thread-safe singleton instance
    static let shared: VersionManager = {
        let instance = VersionManager()
        logInfo("VersionManager singleton created", category: .general)
        return instance
    }()
}