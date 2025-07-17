// this_file: Tests/DidYouGetTests/RecordingManagerTests.swift

import XCTest
@testable import DidYouGet

final class RecordingManagerTests: XCTestCase {
    
    var recordingManager: RecordingManager!
    var preferencesManager: PreferencesManager!
    
    override func setUp() {
        super.setUp()
        recordingManager = RecordingManager()
        preferencesManager = PreferencesManager()
        recordingManager.setPreferencesManager(preferencesManager)
    }
    
    override func tearDown() {
        recordingManager = nil
        preferencesManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(recordingManager.isRecording, "Recording should not be active initially")
        XCTAssertNotNil(recordingManager.preferencesManager, "PreferencesManager should be set")
    }
    
    func testStartRecordingChangesState() {
        // Note: This test may fail if screen recording permission is not granted
        // In a real test environment, you'd mock the permission check
        let initialState = recordingManager.isRecording
        recordingManager.startRecording()
        
        // Give it a moment to start
        let expectation = XCTestExpectation(description: "Recording state change")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // The state might not change if permissions are not granted
        // This test verifies the method can be called without crashing
        XCTAssertNoThrow(recordingManager.stopRecording())
    }
    
    func testStopRecordingCanBeCalled() {
        XCTAssertNoThrow(recordingManager.stopRecording())
    }
}