import Foundation
import Cocoa
import Carbon

@MainActor
class KeyboardTracker: ObservableObject {
    // Threshold for distinguishing tap from hold (in seconds)
    private let tapThreshold: TimeInterval = 0.2
    
    // File handle to write tracking data
    private var outputFileHandle: FileHandle?
    private var outputURL: URL?
    
    // Tracking state
    private var isTracking = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Key state tracking
    private var pressedKeys: [Int: TimeInterval] = [:]
    private var modifierState: [String: Bool] = [
        "Shift": false,
        "Control": false,
        "Option": false,
        "Command": false,
        "Function": false,
        "CapsLock": false
    ]
    
    // Recording start time for relative timestamps
    private var recordingStartTime: Date?
    
    // Privacy settings
    private var maskSensitiveInput = false
    private var sensitiveMode = false
    
    // Keyboard events
    struct KeyEvent: Codable {
        let timestamp: TimeInterval
        let type: EventType
        let key: String
        let modifiers: [String]
        var held_at: TimeInterval?
        var released_at: TimeInterval?
        
        enum EventType: String, Codable {
            case tap
            case hold
            case release
        }
        
        init(timestamp: TimeInterval, type: EventType, key: String, modifiers: [String] = [], held_at: TimeInterval? = nil, released_at: TimeInterval? = nil) {
            self.timestamp = timestamp
            self.type = type
            self.key = key
            self.modifiers = modifiers
            self.held_at = held_at
            self.released_at = released_at
        }
    }
    
    private var events: [KeyEvent] = []
    
    init() {}
    
    func startTracking(outputURL: URL, maskSensitive: Bool = false) {
        guard !isTracking else { return }
        
        self.outputURL = outputURL
        self.maskSensitiveInput = maskSensitive
        
        // Initialize output file
        createOutputFile()
        
        // Reset state
        events = []
        pressedKeys = [:]
        resetModifierState()
        recordingStartTime = Date()
        sensitiveMode = false
        
        // Set up event tap
        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: keyboardEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create keyboard event tap")
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
    
    private func resetModifierState() {
        modifierState = [
            "Shift": false,
            "Control": false,
            "Option": false,
            "Command": false,
            "Function": false,
            "CapsLock": false
        ]
    }
    
    private func relativeTimestamp() -> TimeInterval {
        guard let startTime = recordingStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    private func getActiveModifiers() -> [String] {
        var active: [String] = []
        for (modifier, isActive) in modifierState {
            if isActive {
                active.append(modifier)
            }
        }
        return active
    }
    
    func handleKeyEventData(type eventType: CGEventType, keyCode: Int, flags: CGEventFlags, timestamp externalTimestamp: TimeInterval) {
        let timestamp = relativeTimestamp()
        
        switch eventType {
        case .keyDown:
            handleKeyDownWithData(keyCode: keyCode, flags: flags, timestamp: timestamp)
        case .keyUp:
            handleKeyUpWithData(keyCode: keyCode, flags: flags, timestamp: timestamp)
        case .flagsChanged:
            handleFlagsChangedWithData(keyCode: keyCode, flags: flags, timestamp: timestamp)
        default:
            break
        }
    }
    
    // Kept for compatibility
    func handleKeyEvent(_ cgEvent: CGEvent) {
        let eventType = cgEvent.type
        let keyCode = Int(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        let flags = cgEvent.flags
        let timestamp = relativeTimestamp()
        
        handleKeyEventData(type: eventType, keyCode: keyCode, flags: flags, timestamp: timestamp)
    }
    
    private func handleKeyDownWithData(keyCode: Int, flags: CGEventFlags, timestamp: TimeInterval) {
        // Check for sensitive input mode toggle (e.g., login fields)
        if maskSensitiveInput {
            if keyCode == kVK_Tab || keyCode == kVK_Return {
                sensitiveMode = !sensitiveMode
            }
        }
        
        // Skip modifier keys as they're handled in flagsChanged
        if isModifierKey(keyCode) {
            return
        }
        
        // Record key down time
        pressedKeys[keyCode] = timestamp
    }
    
    private func handleKeyUpWithData(keyCode: Int, flags: CGEventFlags, timestamp: TimeInterval) {
        // Skip modifier keys as they're handled in flagsChanged
        if isModifierKey(keyCode) {
            return
        }
        
        // Create a dummy event for getting key names
        let keyEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        
        // Get the key name
        let keyName = getKeyName(keyCode, keyEvent)
        
        // Get the key down time
        if let keyDownTime = pressedKeys[keyCode] {
            let duration = timestamp - keyDownTime
            let activeModifiers = getActiveModifiers()
            
            if duration < tapThreshold {
                // Quick tap
                let key = sensitiveMode && maskSensitiveInput ? "•" : keyName
                let event = KeyEvent(timestamp: timestamp, type: .tap, key: key, modifiers: activeModifiers)
                addEvent(event)
            } else {
                // Hold - release sequence
                // First, record the hold event (if not already recorded)
                let holdTimestamp = keyDownTime
                let key = sensitiveMode && maskSensitiveInput ? "•" : keyName
                
                // Hold event
                let holdEvent = KeyEvent(timestamp: holdTimestamp, type: .hold, key: key, modifiers: activeModifiers, held_at: holdTimestamp)
                addEvent(holdEvent)
                
                // Release event
                let releaseEvent = KeyEvent(timestamp: timestamp, type: .release, key: key, modifiers: activeModifiers, released_at: timestamp)
                addEvent(releaseEvent)
            }
            
            // Remove from pressed keys
            pressedKeys.removeValue(forKey: keyCode)
        }
    }
    
    private func handleFlagsChangedWithData(keyCode: Int, flags: CGEventFlags, timestamp: TimeInterval) {
        // Determine which modifier key changed
        let (modifier, isPressed) = getModifierStateFromKeyCode(keyCode, flags: flags)
        
        if let modifierName = modifier {
            // Changed state
            let previousState = modifierState[modifierName] ?? false
            
            if isPressed != previousState {
                modifierState[modifierName] = isPressed
                
                if isPressed {
                    // Key down
                    pressedKeys[keyCode] = timestamp
                } else {
                    // Key up - check if it was a tap or hold
                    if let keyDownTime = pressedKeys[keyCode] {
                        let duration = timestamp - keyDownTime
                        let activeModifiers = getActiveModifiers()
                        
                        if duration < tapThreshold {
                            // Quick tap of a modifier key
                            let event = KeyEvent(
                                timestamp: timestamp,
                                type: .tap,
                                key: modifierName,
                                modifiers: activeModifiers.filter { $0 != modifierName } // Remove self from modifiers
                            )
                            addEvent(event)
                        } else {
                            // Hold of a modifier key - record hold and release
                            let holdTimestamp = keyDownTime
                            
                            // Hold event
                            let holdEvent = KeyEvent(
                                timestamp: holdTimestamp,
                                type: .hold,
                                key: modifierName,
                                modifiers: activeModifiers.filter { $0 != modifierName },
                                held_at: holdTimestamp
                            )
                            addEvent(holdEvent)
                            
                            // Release event
                            let releaseEvent = KeyEvent(
                                timestamp: timestamp,
                                type: .release,
                                key: modifierName,
                                modifiers: activeModifiers.filter { $0 != modifierName },
                                released_at: timestamp
                            )
                            addEvent(releaseEvent)
                        }
                        
                        // Remove from pressed keys
                        pressedKeys.removeValue(forKey: keyCode)
                    }
                }
            }
        }
    }
    
    // Keep original methods for compatibility
    private func handleKeyDown(_ event: CGEvent, timestamp: TimeInterval) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        handleKeyDownWithData(keyCode: keyCode, flags: event.flags, timestamp: timestamp)
    }
    
    private func handleKeyUp(_ event: CGEvent, timestamp: TimeInterval) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        handleKeyUpWithData(keyCode: keyCode, flags: event.flags, timestamp: timestamp)
    }
    
    private func handleFlagsChanged(_ event: CGEvent, timestamp: TimeInterval) {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        handleFlagsChangedWithData(keyCode: keyCode, flags: event.flags, timestamp: timestamp)
    }
    
    private func isModifierKey(_ keyCode: Int) -> Bool {
        return keyCode == kVK_Shift || keyCode == kVK_RightShift ||
               keyCode == kVK_Control || keyCode == kVK_RightControl ||
               keyCode == kVK_Option || keyCode == kVK_RightOption ||
               keyCode == kVK_Command || keyCode == kVK_RightCommand ||
               keyCode == kVK_Function ||
               keyCode == kVK_CapsLock
    }
    
    private func getModifierStateFromKeyCode(_ keyCode: Int, flags: CGEventFlags) -> (String?, Bool) {
        switch keyCode {
        case kVK_Shift, kVK_RightShift:
            return ("Shift", flags.contains(.maskShift))
        case kVK_Control, kVK_RightControl:
            return ("Control", flags.contains(.maskControl))
        case kVK_Option, kVK_RightOption:
            return ("Option", flags.contains(.maskAlternate))
        case kVK_Command, kVK_RightCommand:
            return ("Command", flags.contains(.maskCommand))
        case kVK_Function:
            return ("Function", flags.contains(.maskSecondaryFn))
        case kVK_CapsLock:
            return ("CapsLock", flags.contains(.maskAlphaShift))
        default:
            return (nil, false)
        }
    }
    
    private func getKeyName(_ keyCode: Int, _ event: CGEvent) -> String {
        var name = "Unknown"
        
        let keyboardLayout = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        if let layoutData = TISGetInputSourceProperty(keyboardLayout, kTISPropertyUnicodeKeyLayoutData) {
            let dataRef = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as CFData
            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)
            
            var deadKeyState: UInt32 = 0
            var stringLength = 0
            var unicodeString = [UniChar](repeating: 0, count: 4)
            
            // Get the character representation
            let status = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(0), // Down action
                UInt32(0),
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                4,
                &stringLength,
                &unicodeString
            )
            
            if status == noErr {
                if stringLength > 0 {
                    // Convert the character to a string
                    name = String(utf16CodeUnits: unicodeString, count: stringLength)
                    
                    // Handle special keys
                    if name.isEmpty || name == "\r" {
                        name = getSpecialKeyName(keyCode)
                    }
                } else {
                    name = getSpecialKeyName(keyCode)
                }
            }
        }
        
        return name
    }
    
    private func getSpecialKeyName(_ keyCode: Int) -> String {
        switch keyCode {
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Space: return "Space"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Escape"
        case kVK_ForwardDelete: return "ForwardDelete"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "PageUp"
        case kVK_PageDown: return "PageDown"
        case kVK_LeftArrow: return "LeftArrow"
        case kVK_RightArrow: return "RightArrow"
        case kVK_DownArrow: return "DownArrow"
        case kVK_UpArrow: return "UpArrow"
        default: return "Key_\(keyCode)"
        }
    }
    
    private func addEvent(_ event: KeyEvent) {
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
              "threshold_ms": \(Int(tapThreshold * 1000)),
              "events": [
            
            """
            
            outputFileHandle?.write(Data(header.utf8))
        } catch {
            print("Failed to create keyboard tracking output file: \(error)")
        }
    }
    
    private func writeEventToFile(_ event: KeyEvent) {
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
            print("Failed to write keyboard event to file: \(error)")
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
        
        print("Keyboard tracking data saved to: \(outputURL?.path ?? "unknown")")
    }
}

// Global callback function for keyboard events
private func keyboardEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Get the KeyboardTracker instance from the user info
    guard let userInfo = userInfo else {
        return Unmanaged.passRetained(event)
    }
    
    let tracker = Unmanaged<KeyboardTracker>.fromOpaque(userInfo).takeUnretainedValue()
    
    // Extract necessary data from the event to avoid data races
    let eventType = event.type
    let timestamp = Date().timeIntervalSinceReferenceDate
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    
    // Handle the event on the main thread
    DispatchQueue.main.async {
        tracker.handleKeyEventData(type: eventType, keyCode: keyCode, flags: flags, timestamp: timestamp)
    }
    
    // Pass the event through to the application
    return Unmanaged.passRetained(event)
}