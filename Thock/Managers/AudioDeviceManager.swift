import Foundation
import CoreAudio
import OSLog

final class AudioDeviceManager {
    static let shared = AudioDeviceManager()
    
    // MARK: - Types
    
    /// Represents an audio output device
    struct AudioDevice: Identifiable, Equatable, Hashable {
        let id: String // uid
        let name: String
        let deviceID: AudioDeviceID
        
        static let systemDefault = AudioDevice(
            id: "system-default",
            name: "System Default",
            deviceID: 0
        )
    }
    
    // MARK: - State
    
    private var availableDevices: [AudioDevice] = []
    private let deviceListLock = NSLock()
    private var isMonitoring = false
    private var deviceListListenerAddress: AudioObjectPropertyAddress?
    private var defaultDeviceListenerAddress: AudioObjectPropertyAddress?
    
    // MARK: - Initialization
    
    private init() {
        enumerateAndCacheDevices()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public API
    
    /// Returns list of available audio output devices
    /// - Returns: Array of AudioDevice including system default option
    func getAvailableOutputDevices() -> [AudioDevice] {
        deviceListLock.lock()
        defer { deviceListLock.unlock() }
        
        // add system as a first item
        var devices = [AudioDevice.systemDefault]
        devices.append(contentsOf: availableDevices)
        
        return devices
    }
    
    /// Returns the current system default output device
    func getSystemDefaultDevice() -> AudioDevice? {
        guard let deviceID = getSystemDefaultDeviceID() else {
            return nil
        }
        
        guard let uid = getDeviceUID(deviceID),
              let name = getDeviceName(deviceID) else {
            return nil
        }
        
        return AudioDevice(id: uid, name: name, deviceID: deviceID)
    }
    
    /// Finds a device by its UID
    func findDevice(byUID uid: String) -> AudioDevice? {
        deviceListLock.lock()
        defer { deviceListLock.unlock() }
        
        return availableDevices.first { $0.id == uid }
    }
    
    /// Starts monitoring for device changes
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        setupDeviceListListener()
        setupDefaultDeviceListener()
        isMonitoring = true
        Logger.audio.info("Started monitoring audio device changes")
    }
    
    /// Stops monitoring for device changes
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        if let address = deviceListListenerAddress {
            var mutableAddress = address
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &mutableAddress,
                deviceListChangedCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
        
        if let address = defaultDeviceListenerAddress {
            var mutableAddress = address
            AudioObjectRemovePropertyListener(
                AudioObjectID(kAudioObjectSystemObject),
                &mutableAddress,
                defaultDeviceChangedCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
        
        isMonitoring = false
        deviceListListenerAddress = nil
        defaultDeviceListenerAddress = nil
        Logger.audio.info("Stopped monitoring audio device changes")
    }
    
    /// Re-enumerates and caches all available audio devices.
    func enumerateAndCacheDevices() {
        deviceListLock.lock()
        defer { deviceListLock.unlock() }
        
        availableDevices = enumerateOutputDevices()
        Logger.audio.debug("Enumerated \(self.availableDevices.count) audio output devices")
    }
    
    // MARK: - Private Methods - Device Enumeration
    
    private func enumerateOutputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // all
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            Logger.audio.error("Failed to get audio device list size: \(status)")
            return devices
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else {
            Logger.audio.error("Failed to get audio device list: \(status)")
            return devices
        }
        
        for deviceID in deviceIDs {
            if isOutputDevice(deviceID),
               let uid = getDeviceUID(deviceID),
               let name = getDeviceName(deviceID) {
                let device = AudioDevice(id: uid, name: name, deviceID: deviceID)
                devices.append(device)
            }
        }
        
        return devices
    }
    
    private func isOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr && dataSize > 0 else {
            return false
        }
        
        // Allocate buffer list
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        let getDataStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        )
        
        guard getDataStatus == noErr else {
            return false
        }
        
        let bufferList = bufferListPointer.pointee
        return bufferList.mNumberBuffers > 0
    }
    
    private func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceUID: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceUID
        )
        
        guard status == noErr, let uid = deviceUID?.takeRetainedValue() as String? else {
            return nil
        }
        
        return uid
    }
    
    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceName: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )
        
        guard status == noErr, let name = deviceName?.takeRetainedValue() as String? else {
            return nil
        }
        
        return name
    }
    
    private func getSystemDefaultDeviceID() -> AudioDeviceID? {
        var defaultDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        
        return status == noErr ? defaultDeviceID : nil
    }
    
    // MARK: - Private Methods - Device Monitoring
    
    private func setupDeviceListListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            deviceListChangedCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if status == noErr {
            deviceListListenerAddress = propertyAddress
            Logger.audio.debug("Audio device list listener added successfully")
        } else {
            Logger.audio.error("Failed to add device list listener: \(status)")
        }
    }
    
    private func setupDefaultDeviceListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            defaultDeviceChangedCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if status == noErr {
            defaultDeviceListenerAddress = propertyAddress
            Logger.audio.debug("Default device listener added successfully")
        } else {
            Logger.audio.error("Failed to add default device listener: \(status)")
        }
    }
    
    fileprivate func handleDefaultDeviceChange() {
        Logger.audio.info("System default audio device changed")
        NotificationCenter.default.post(
            name: .systemDefaultAudioDeviceDidChange,
            object: nil
        )
    }
    
    fileprivate func handleDeviceListChange() {
        Logger.audio.info("Audio device list changed, re-enumerating devices")
        enumerateAndCacheDevices()
        NotificationCenter.default.post(
            name: .audioDeviceListDidChange,
            object: nil
        )
    }
}

// MARK: - Callback

private func deviceListChangedCallback(
    _ inObjectID: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else {
        return noErr
    }
    
    let manager = Unmanaged<AudioDeviceManager>.fromOpaque(clientData).takeUnretainedValue()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak manager] in
        manager?.handleDeviceListChange()
    }
    
    return noErr
}

// MARK: - Callback for default device change

private func defaultDeviceChangedCallback(
    _ inObjectID: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else {
        return noErr
    }
    
    let manager = Unmanaged<AudioDeviceManager>.fromOpaque(clientData).takeUnretainedValue()
    
    DispatchQueue.main.async {
        manager.handleDefaultDeviceChange()
    }
    
    return noErr
}

// MARK: - Notification Extension

extension Notification.Name {
    static let audioDeviceListDidChange = Notification.Name("audioDeviceListDidChange")
    static let systemDefaultAudioDeviceDidChange = Notification.Name("systemDefaultAudioDeviceDidChange")
}
