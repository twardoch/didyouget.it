// this_file: Tests/DidYouGetTests/VersionManagerTests.swift

import XCTest
@testable import DidYouGet

final class VersionManagerTests: XCTestCase {
    
    func testVersionManagerSingleton() {
        let manager1 = VersionManager.shared
        let manager2 = VersionManager.shared
        XCTAssertTrue(manager1 === manager2, "VersionManager should be a singleton")
    }
    
    func testCurrentVersionIsNotEmpty() {
        let version = VersionManager.shared.currentVersion
        XCTAssertFalse(version.isEmpty, "Current version should not be empty")
    }
    
    func testVersionFormat() {
        let version = VersionManager.shared.currentVersion
        let versionPattern = #"^\d+\.\d+\.\d+.*$"#
        let regex = try! NSRegularExpression(pattern: versionPattern)
        let range = NSRange(location: 0, length: version.utf16.count)
        let match = regex.firstMatch(in: version, options: [], range: range)
        XCTAssertNotNil(match, "Version should follow semantic versioning format")
    }
    
    func testBuildNumberIsNumeric() {
        let buildNumber = VersionManager.shared.buildNumber
        XCTAssertTrue(Int(buildNumber) != nil, "Build number should be numeric")
    }
    
    func testCommitHashIsNotEmpty() {
        let commitHash = VersionManager.shared.commitHash
        XCTAssertFalse(commitHash.isEmpty, "Commit hash should not be empty")
    }
    
    func testFullVersionString() {
        let fullVersion = VersionManager.shared.fullVersionString
        XCTAssertFalse(fullVersion.isEmpty, "Full version string should not be empty")
        XCTAssertTrue(fullVersion.contains("build"), "Full version should contain build info")
    }
}