import Foundation
import AVFoundation

@MainActor
class AudioManager {
    static let shared = AudioManager()
    
    struct AudioDevice: Identifiable, Hashable {
        let id: String
        let name: String
        let deviceID: AudioDeviceID
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    private init() {}
    
    func getAudioDevices() -> [AudioDevice] {
        var deviceList = [AudioDevice]()
        
        var propertySize: UInt32 = 0
        var getPropertyAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get the size of the property value
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &getPropertyAddr,
            0,
            nil,
            &propertySize
        )
        
        if status != noErr {
            print("Error getting audio devices property size: \(status)")
            return deviceList
        }
        
        // Calculate the number of devices
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        
        // Create a buffer to hold the device IDs
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        // Get the device IDs
        let status2 = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getPropertyAddr,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        if status2 != noErr {
            print("Error getting audio devices: \(status2)")
            return deviceList
        }
        
        // Iterate through each device
        for deviceID in deviceIDs {
            // Check if it's an input device
            var inputChannels: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            var propertyAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyDataSize(
                deviceID,
                &propertyAddr,
                0,
                nil,
                &propertySize
            )
            
            if status == noErr {
                let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propertySize))
                
                let status2 = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddr,
                    0,
                    nil,
                    &propertySize,
                    bufferList
                )
                
                if status2 == noErr {
                    let bufferListPtr = UnsafeMutableAudioBufferListPointer(bufferList)
                    for buffer in bufferListPtr {
                        inputChannels += buffer.mNumberChannels
                    }
                }
                
                bufferList.deallocate()
            }
            
            // Only add devices with input channels
            if inputChannels > 0 {
                // Get the device name
                var name: CFString = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                var namePropertyAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioObjectPropertyName,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                let nameStatus = AudioObjectGetPropertyData(
                    deviceID,
                    &namePropertyAddr,
                    0,
                    nil,
                    &nameSize,
                    &name
                )
                
                if nameStatus == noErr {
                    let device = AudioDevice(
                        id: "\(deviceID)",
                        name: name as String,
                        deviceID: deviceID
                    )
                    deviceList.append(device)
                }
            }
        }
        
        return deviceList
    }
    
    // Get the default input device
    func getDefaultInputDevice() -> AudioDevice? {
        var defaultInputDeviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddr,
            0,
            nil,
            &propertySize,
            &defaultInputDeviceID
        )
        
        if status == noErr && defaultInputDeviceID != 0 {
            // Get the device name
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            var namePropertyAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let nameStatus = AudioObjectGetPropertyData(
                defaultInputDeviceID,
                &namePropertyAddr,
                0,
                nil,
                &nameSize,
                &name
            )
            
            if nameStatus == noErr {
                return AudioDevice(
                    id: "\(defaultInputDeviceID)",
                    name: name as String,
                    deviceID: defaultInputDeviceID
                )
            }
        }
        
        return nil
    }
}