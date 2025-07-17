// this_file: Tests/DidYouGetTests/PreferencesManagerTests.swift

import XCTest
@testable import DidYouGet

final class PreferencesManagerTests: XCTestCase {
    
    var preferencesManager: PreferencesManager!
    
    override func setUp() {
        super.setUp()
        preferencesManager = PreferencesManager()
    }
    
    override func tearDown() {
        preferencesManager = nil
        super.tearDown()
    }
    
    func testInitialValues() {
        XCTAssertNotNil(preferencesManager.selectedScreenID, "Selected screen ID should have a default value")
        XCTAssertNotNil(preferencesManager.selectedAudioDevice, "Selected audio device should have a default value")
        XCTAssertNotNil(preferencesManager.outputDirectory, "Output directory should have a default value")
    }
    
    func testOutputDirectoryIsValid() {
        let outputDir = preferencesManager.outputDirectory
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputDir), "Output directory should exist")
    }
    
    func testVideoQualityDefaultValue() {
        // Test that video quality has a reasonable default
        XCTAssertGreaterThan(preferencesManager.videoQuality, 0.0, "Video quality should be greater than 0")
        XCTAssertLessThanOrEqual(preferencesManager.videoQuality, 1.0, "Video quality should be less than or equal to 1")
    }
}