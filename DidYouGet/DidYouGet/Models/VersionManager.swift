// this_file: DidYouGet/DidYouGet/Models/VersionManager.swift

import Foundation

/// Manages semantic versioning based on git tags
class VersionManager {
    static let shared = VersionManager()
    
    private init() {}
    
    /// Current version from git tags or fallback
    var currentVersion: String {
        return getVersionFromGit() ?? "1.0.0"
    }
    
    /// Get version from git tags
    private func getVersionFromGit() -> String? {
        // Try to get version from git describe first
        if let version = executeGitCommand(["describe", "--tags", "--exact-match", "HEAD"]) {
            return cleanVersionString(version)
        }
        
        // Fallback to latest tag
        if let version = executeGitCommand(["describe", "--tags", "--abbrev=0"]) {
            return cleanVersionString(version)
        }
        
        return nil
    }
    
    /// Execute git command and return output
    private func executeGitCommand(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Error executing git command: \(error)")
            return nil
        }
    }
    
    /// Clean version string by removing 'v' prefix and extra characters
    private func cleanVersionString(_ version: String) -> String {
        var cleaned = version
        
        // Remove 'v' prefix if present
        if cleaned.hasPrefix("v") {
            cleaned = String(cleaned.dropFirst())
        }
        
        // Remove any additional git describe info (like -1-g123abc)
        if let range = cleaned.range(of: "-") {
            cleaned = String(cleaned[..<range.lowerBound])
        }
        
        return cleaned
    }
    
    /// Check if current version is a release version (exact tag match)
    var isReleaseVersion: Bool {
        return executeGitCommand(["describe", "--tags", "--exact-match", "HEAD"]) != nil
    }
    
    /// Get build number from git commit count
    var buildNumber: String {
        return executeGitCommand(["rev-list", "--count", "HEAD"]) ?? "0"
    }
    
    /// Get git commit hash
    var commitHash: String {
        return executeGitCommand(["rev-parse", "--short", "HEAD"]) ?? "unknown"
    }
    
    /// Get full version string with build info
    var fullVersionString: String {
        let version = currentVersion
        let build = buildNumber
        let commit = commitHash
        
        if isReleaseVersion {
            return "\(version) (build \(build))"
        } else {
            return "\(version)-dev (build \(build), commit \(commit))"
        }
    }
}