//
//  Logger.swift
//  DidYouGet
//
//  Centralized logging infrastructure
//
// this_file: DidYouGet/DidYouGet/Utilities/Logger.swift

import Foundation
import os.log

// MARK: - Log Categories

enum LogCategory: String {
    case general = "General"
    case recording = "Recording"
    case video = "Video"
    case audio = "Audio"
    case capture = "Capture"
    case ui = "UI"
    case preferences = "Preferences"
    case fileIO = "FileIO"
    case permissions = "Permissions"
    case error = "Error"
    
    var osLogCategory: String {
        "it.didyouget.mac.\(rawValue)"
    }
}

// MARK: - Log Level

enum LogLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .default
        case .error:
            return .error
        case .critical:
            return .fault
        }
    }
    
    var icon: String {
        switch self {
        case .verbose:
            return "🔍"
        case .debug:
            return "🐛"
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .critical:
            return "🚨"
        }
    }
}

// MARK: - Logger

class Logger {
    
    // MARK: - Singleton
    
    static let shared = Logger()
    
    // MARK: - Properties
    
    private var osLoggers: [LogCategory: OSLog] = [:]
    private let queue = DispatchQueue(label: "it.didyouget.mac.logger", attributes: .concurrent)
    
    // Configuration
    var minimumLogLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()
    
    var enableFileLogging = false
    var logFileURL: URL?
    
    // MARK: - Initialization
    
    private init() {
        setupLoggers()
        setupFileLogging()
    }
    
    private func setupLoggers() {
        for category in LogCategory.allCases {
            osLoggers[category] = OSLog(
                subsystem: Bundle.main.bundleIdentifier ?? "it.didyouget.mac",
                category: category.osLogCategory
            )
        }
    }
    
    private func setupFileLogging() {
        #if DEBUG
        enableFileLogging = true
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("DidYouGetIt/Logs")
        
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "didyougetit_\(dateFormatter.string(from: Date())).log"
        
        logFileURL = logsDirectory.appendingPathComponent(filename)
        #endif
    }
    
    // MARK: - Logging Methods
    
    func log(_ message: String,
             level: LogLevel = .info,
             category: LogCategory = .general,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        guard level >= minimumLogLevel else { return }
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = formatMessage(message, level: level, category: category, file: filename, function: function, line: line)
        
        // OS Log
        if let osLog = osLoggers[category] {
            os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        }
        
        // File logging
        if enableFileLogging {
            writeToFile(logMessage)
        }
        
        // Console output in debug
        #if DEBUG
        print(logMessage)
        #endif
    }
    
    // MARK: - Convenience Methods
    
    func verbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .verbose, category: category, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Error Logging
    
    func logError(_ error: Error, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        let errorMessage = "Error: \(error.localizedDescription)"
        log(errorMessage, level: .error, category: category, file: file, function: function, line: line)
        
        // Log additional error details if available
        if let recordingError = error as? RecordingError {
            if let suggestion = recordingError.recoverySuggestion {
                log("Recovery suggestion: \(suggestion)", level: .info, category: category, file: file, function: function, line: line)
            }
        }
    }
    
    // MARK: - Performance Logging
    
    func measureTime<T>(label: String, category: LogCategory = .general, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(label) took \(String(format: "%.3f", timeElapsed)) seconds", category: category)
        }
        return try operation()
    }
    
    func measureTimeAsync<T>(label: String, category: LogCategory = .general, operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            debug("⏱️ \(label) took \(String(format: "%.3f", timeElapsed)) seconds", category: category)
        }
        return try await operation()
    }
    
    // MARK: - Private Methods
    
    private func formatMessage(_ message: String,
                              level: LogLevel,
                              category: LogCategory,
                              file: String,
                              function: String,
                              line: Int) -> String {
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let threadName = Thread.current.name ?? "Unknown"
        let threadID = Thread.current.isMainThread ? "Main" : threadName
        
        return "\(timestamp) [\(category.rawValue)] \(level.icon) [\(threadID)] \(file):\(line) - \(function) - \(message)"
    }
    
    private func writeToFile(_ message: String) {
        queue.async(flags: .barrier) { [weak self] in
            guard let url = self?.logFileURL else { return }
            
            let messageWithNewline = message + "\n"
            
            if let data = messageWithNewline.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: url.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: url) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
    
    // MARK: - Log Management
    
    func clearLogs() {
        guard let url = logFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        setupFileLogging()
    }
    
    func exportLogs() -> URL? {
        return logFileURL
    }
    
    func pruneOldLogs(daysToKeep: Int = 7) {
        guard let logsDirectory = logFileURL?.deletingLastPathComponent() else { return }
        
        let fileManager = FileManager.default
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -daysToKeep, to: Date()) ?? Date()
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in logFiles {
                if let creationDate = try fileURL.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    debug("Pruned old log file: \(fileURL.lastPathComponent)", category: .fileIO)
                }
            }
        } catch {
            error("Failed to prune old logs: \(error)", category: .fileIO)
        }
    }
}

// MARK: - Extensions

extension LogCategory: CaseIterable {}

// MARK: - Global Convenience Functions

func logVerbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.verbose(message, category: category, file: file, function: function, line: line)
}

func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logCritical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, category: category, file: file, function: function, line: line)
}