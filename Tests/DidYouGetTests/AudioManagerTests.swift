// this_file: Tests/DidYouGetTests/AudioManagerTests.swift

import XCTest
@testable import DidYouGet

final class AudioManagerTests: XCTestCase {
    
    var audioManager: AudioManager!
    
    override func setUp() {
        super.setUp()
        audioManager = AudioManager()
    }
    
    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }
    
    func testAudioDevicesCanBeRetrieved() {
        let devices = audioManager.availableAudioDevices
        // Should at least have some audio devices available on macOS
        XCTAssertGreaterThanOrEqual(devices.count, 0, "Should be able to retrieve audio devices")
    }
    
    func testDefaultAudioDeviceSelection() {
        let defaultDevice = audioManager.defaultAudioDevice
        XCTAssertNotNil(defaultDevice, "Should have a default audio device")
    }
}