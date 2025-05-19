import Foundation
import Cocoa
import Carbon

@MainActor
class MouseTracker: ObservableObject {
    // Threshold for distinguishing click from hold (in seconds)
    private let clickThreshold: TimeInterval = 0.2
    
    // File handle to write tracking data
    private var outputFileHandle: FileHandle?
    private var outputURL: URL?
    
    // Tracking state
    private var isTracking = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Current mouse button state
    private var leftButtonDown = false
    private var rightButtonDown = false
    private var leftButtonDownTime: TimeInterval = 0
    private var rightButtonDownTime: TimeInterval = 0
    
    // Recording start time for relative timestamps
    private var recordingStartTime: Date?
    
    // Mouse events
    struct MouseEvent: Codable {
        let timestamp: TimeInterval
        let type: EventType
        let x: Int
        let y: Int
        let button: String?
        var held_at: TimeInterval?
        var released_at: TimeInterval?
        
        enum EventType: String, Codable {
            case move
            case click
            case press
            case release
            case drag
        }
        
        init(timestamp: TimeInterval, type: EventType, x: Int, y: Int, button: String? = nil, held_at: TimeInterval? = nil, released_at: TimeInterval? = nil) {
            self.timestamp = timestamp
            self.type = type
            self.x = x
            self.y = y
            self.button = button
            self.held_at = held_at
            self.released_at = released_at
        }
    }
    
    private var events: [MouseEvent] = []
    
    init() {}
    
    func startTracking(outputURL: URL) {
        guard !isTracking else { return }
        
        self.outputURL = outputURL
        
        // Initialize output file
        createOutputFile()
        
        // Reset state
        events = []
        leftButtonDown = false
        rightButtonDown = false
        recordingStartTime = Date()
        
        // Set up event tap
        // Create event mask
        let mouseMoved = (1 << CGEventType.mouseMoved.rawValue)
        let leftMouseDown = (1 << CGEventType.leftMouseDown.rawValue)
        let leftMouseUp = (1 << CGEventType.leftMouseUp.rawValue)
        let rightMouseDown = (1 << CGEventType.rightMouseDown.rawValue)
        let rightMouseUp = (1 << CGEventType.rightMouseUp.rawValue)
        let leftMouseDragged = (1 << CGEventType.leftMouseDragged.rawValue)
        let rightMouseDragged = (1 << CGEventType.rightMouseDragged.rawValue)
        
        let eventMask = CGEventMask(mouseMoved | leftMouseDown | leftMouseUp | rightMouseDown | rightMouseUp | leftMouseDragged | rightMouseDragged)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: mouseEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        isTracking = true
    }
    
    func stopTracking() {
        guard isTracking else { return }
        
        // Stop event tap
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        
        // Finalize and close output file
        finalizeOutputFile()
        
        isTracking = false
    }
    
    private func relativeTimestamp() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    func handleMouseEventData(type eventType: CGEventType, location: CGPoint, timestamp externalTimestamp: TimeInterval, clickState: Int64 = 0) {
        let timestamp = relativeTimestamp()
        
        // Create event based on type
        switch eventType {
        case .mouseMoved:
            let event = MouseEvent(timestamp: timestamp, type: .move, x: Int(location.x), y: Int(location.y))
            addEvent(event)
            
        case .leftMouseDown:
            leftButtonDown = true
            leftButtonDownTime = timestamp
            
        case .leftMouseUp:
            if leftButtonDown {
                let duration = timestamp - leftButtonDownTime
                if duration < clickThreshold {
                    // Quick press - register as click
                    let event = MouseEvent(timestamp: timestamp, type: .click, x: Int(location.x), y: Int(location.y), button: "left")
                    addEvent(event)
                } else {
                    // Long press - register as release (press was registered at mouseDown)
                    let event = MouseEvent(timestamp: timestamp, type: .release, x: Int(location.x), y: Int(location.y), button: "left", released_at: timestamp)
                    addEvent(event)
                }
                leftButtonDown = false
            }
            
        case .rightMouseDown:
            rightButtonDown = true
            rightButtonDownTime = timestamp
            
        case .rightMouseUp:
            if rightButtonDown {
                let duration = timestamp - rightButtonDownTime
                if duration < clickThreshold {
                    // Quick press - register as click
                    let event = MouseEvent(timestamp: timestamp, type: .click, x: Int(location.x), y: Int(location.y), button: "right")
                    addEvent(event)
                } else {
                    // Long press - register as release (press was registered at mouseDown)
                    let event = MouseEvent(timestamp: timestamp, type: .release, x: Int(location.x), y: Int(location.y), button: "right", released_at: timestamp)
                    addEvent(event)
                }
                rightButtonDown = false
            }
            
        case .leftMouseDragged:
            // If first drag event after mouse down, register the press
            if leftButtonDown && timestamp - leftButtonDownTime < 0.1 {
                let pressEvent = MouseEvent(timestamp: leftButtonDownTime, type: .press, x: Int(location.x), y: Int(location.y), button: "left", held_at: leftButtonDownTime)
                addEvent(pressEvent)
            }
            
            // Register drag movement
            let event = MouseEvent(timestamp: timestamp, type: .drag, x: Int(location.x), y: Int(location.y))
            addEvent(event)
            
        case .rightMouseDragged:
            // If first drag event after mouse down, register the press
            if rightButtonDown && timestamp - rightButtonDownTime < 0.1 {
                let pressEvent = MouseEvent(timestamp: rightButtonDownTime, type: .press, x: Int(location.x), y: Int(location.y), button: "right", held_at: rightButtonDownTime)
                addEvent(pressEvent)
            }
            
            // Register drag movement
            let event = MouseEvent(timestamp: timestamp, type: .drag, x: Int(location.x), y: Int(location.y))
            addEvent(event)
            
        default:
            break
        }
    }
    
    // Kept for compatibility
    func handleMouseEvent(_ cgEvent: CGEvent) {
        handleMouseEventData(type: cgEvent.type, location: cgEvent.location, timestamp: Date().timeIntervalSinceReferenceDate)
    }
    
    private func addEvent(_ event: MouseEvent) {
        events.append(event)
        writeEventToFile(event)
    }
    
    private func createOutputFile() {
        guard let url = outputURL else { return }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Create the file and write header
        FileManager.default.createFile(atPath: url.path, contents: nil)
        
        do {
            outputFileHandle = try FileHandle(forWritingTo: url)
            
            // Write the start of JSON array
            let header = """
            {
              "version": "2.0",
              "recording_start": "\(ISO8601DateFormatter().string(from: recordingStartTime ?? Date()))",
              "threshold_ms": \(Int(clickThreshold * 1000)),
              "events": [
            
            """
            
            outputFileHandle?.write(Data(header.utf8))
        } catch {
            print("Failed to create mouse tracking output file: \(error)")
        }
    }
    
    private func writeEventToFile(_ event: MouseEvent) {
        guard let fileHandle = outputFileHandle else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            
            let jsonData = try encoder.encode(event)
            
            // Convert to string to add comma
            var jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            jsonString += ",\n"
            
            // Write to file
            fileHandle.write(Data(jsonString.utf8))
        } catch {
            print("Failed to write mouse event to file: \(error)")
        }
    }
    
    private func finalizeOutputFile() {
        guard let fileHandle = outputFileHandle else { return }
        
        // Remove trailing comma and close the JSON array
        fileHandle.seekToEndOfFile()
        let currentPos = fileHandle.offsetInFile
        if currentPos > 2 {
            fileHandle.truncateFile(atOffset: currentPos - 2)
            fileHandle.seekToEndOfFile()
        }
        
        let footer = """
        
          ]
        }
        """
        
        fileHandle.write(Data(footer.utf8))
        fileHandle.closeFile()
        outputFileHandle = nil
        
        print("Mouse tracking data saved to: \(outputURL?.path ?? "unknown")")
    }
}

// Global callback function for mouse events
private func mouseEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Get the MouseTracker instance from the user info
    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }
    
    let tracker = Unmanaged<MouseTracker>.fromOpaque(userInfo).takeUnretainedValue()
    
    // Extract necessary data from the event to avoid data races
    let eventType = event.type
    let location = event.location
    let timestamp = Date().timeIntervalSinceReferenceDate
    
    // Extract click state for mouse buttons if relevant
    var clickState: Int64 = 0
    if eventType == .leftMouseDown || eventType == .leftMouseUp ||
       eventType == .rightMouseDown || eventType == .rightMouseUp {
        clickState = event.getIntegerValueField(.mouseEventClickState)
    }
    
    // Handle the event on the main thread
    DispatchQueue.main.async {
        tracker.handleMouseEventData(type: eventType, location: location, timestamp: timestamp, clickState: clickState)
    }
    
    // Pass the event through to the application
    return Unmanaged.passRetained(event)
}