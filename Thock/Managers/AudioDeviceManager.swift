import Foundation
import CoreAudio
import AudioToolbox
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
    private var volumeListenerAddresses: [AudioObjectPropertyAddress] = []
    private var monitoredVolumeDeviceID: AudioDeviceID?
    
    // Debouncing for device list changes
    private var deviceListChangeWorkItem: DispatchWorkItem?
    private let workItemLock = NSLock()
    private let debounceDelay: TimeInterval = 0.5
    
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
    
    /// Starts monitoring for device changes and volume
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        setupDeviceListListener()
        setupDefaultDeviceListener()
        updateVolumeListener()
        recalculateCompensationMultiplier()
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
        
        removeVolumeListener()
        
        // Cancel any pending debounced work
        workItemLock.lock()
        deviceListChangeWorkItem?.cancel()
        deviceListChangeWorkItem = nil
        workItemLock.unlock()
        
        isMonitoring = false
        deviceListListenerAddress = nil
        defaultDeviceListenerAddress = nil
        Logger.audio.info("Stopped monitoring audio device changes")
    }
    
    // MARK: - Volume Monitoring
    
    /// Returns the volume scalar (0.0 - 1.0) of a specific device or default device.
    func getDeviceVolume(_ deviceID: AudioDeviceID? = nil) -> Float {
        guard let targetDeviceID = deviceID ?? getSystemDefaultDeviceID() else {
            return 1.0
        }
        
        var volume: Float32 = 1.0
        var size = UInt32(MemoryLayout<Float32>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(targetDeviceID, &address) {
            let status = AudioObjectGetPropertyData(targetDeviceID, &address, 0, nil, &size, &volume)
            if status == noErr {
                return volume
            }
        }
        
        // Fallback to kAudioDevicePropertyVolumeScalar
        address.mSelector = kAudioDevicePropertyVolumeScalar
        if AudioObjectHasProperty(targetDeviceID, &address) {
            let status = AudioObjectGetPropertyData(targetDeviceID, &address, 0, nil, &size, &volume)
            if status == noErr {
                return volume
            }
        }
        
        // Fallback to channel 1
        address.mElement = 1
        if AudioObjectHasProperty(targetDeviceID, &address) {
            let status = AudioObjectGetPropertyData(targetDeviceID, &address, 0, nil, &size, &volume)
            if status == noErr {
                return volume
            }
        }
        
        return 1.0
    }
    
    /// Converts a volume scalar (0.0 - 1.0) to hardware decibels using CoreAudio hardware device curve.
    func getDeviceDecibels(for scalar: Float, deviceID: AudioDeviceID? = nil) -> Float {
        guard let targetDeviceID = deviceID ?? getSystemDefaultDeviceID() else {
            return -60.0 * (1.0 - max(0.0, min(1.0, scalar)))
        }
        
        var val = Float32(scalar)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalarToDecibels,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(targetDeviceID, &address) {
            let status = AudioObjectGetPropertyData(targetDeviceID, &address, 0, nil, &size, &val)
            if status == noErr {
                return val
            }
        }
        
        // Fallback: standard macOS dB transfer curve (-60dB at 0.0 to 0dB at 1.0)
        return -60.0 * (1.0 - max(0.0, min(1.0, scalar)))
    }
    
    /// Returns the true physical hardware acoustic amplitude (0.0 - 1.0) for a given volume scalar.
    func getHardwareAmplitude(for scalar: Float, deviceID: AudioDeviceID? = nil) -> Float {
        let db = getDeviceDecibels(for: scalar, deviceID: deviceID)
        return pow(10.0, db / 20.0)
    }
    
    /// Sets up or updates the volume listener for the current output device.
    func updateVolumeListener(for deviceID: AudioDeviceID? = nil) {
        removeVolumeListener()
        
        guard let targetDeviceID = deviceID ?? getSystemDefaultDeviceID() else { return }
        
        let candidateAddresses: [AudioObjectPropertyAddress] = [
            AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 1
            ),
            AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: 2
            )
        ]
        
        var addedAddresses: [AudioObjectPropertyAddress] = []
        
        for var addr in candidateAddresses {
            if AudioObjectHasProperty(targetDeviceID, &addr) {
                let status = AudioObjectAddPropertyListener(
                    targetDeviceID,
                    &addr,
                    deviceVolumeChangedCallback,
                    Unmanaged.passUnretained(self).toOpaque()
                )
                if status == noErr {
                    addedAddresses.append(addr)
                }
            }
        }
        
        if !addedAddresses.isEmpty {
            volumeListenerAddresses = addedAddresses
            monitoredVolumeDeviceID = targetDeviceID
            Logger.audio.debug("Added \(addedAddresses.count) volume listeners for device ID \(targetDeviceID)")
        }
    }
    
    private func removeVolumeListener() {
        guard let deviceID = monitoredVolumeDeviceID else { return }
        for var addr in volumeListenerAddresses {
            AudioObjectRemovePropertyListener(
                deviceID,
                &addr,
                deviceVolumeChangedCallback,
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
        volumeListenerAddresses.removeAll()
        monitoredVolumeDeviceID = nil
    }
    
    private var _cachedCompensationMultiplier: Float = 1.0
    
    /// Cached volume compensation multiplier for zero-latency lock-free audio buffer rendering.
    var cachedCompensationMultiplier: Float {
        return _cachedCompensationMultiplier
    }
    
    /// Recalculates and caches the compensation multiplier.
    func recalculateCompensationMultiplier() {
        guard let targetDeviceID = getSystemDefaultDeviceID() else {
            _cachedCompensationMultiplier = 1.0
            return
        }
        
        let sysVol = getDeviceVolume(targetDeviceID)
        if sysVol <= 0.005 {
            _cachedCompensationMultiplier = 0.0
            return
        }
        
        // Nominal reference level at 80% macOS system slider (-12.7 dB standard listening baseline)
        let refScalar: Float = 0.80
        let refDB = getDeviceDecibels(for: refScalar, deviceID: targetDeviceID)
        let currentDB = getDeviceDecibels(for: sysVol, deviceID: targetDeviceID)
        
        // Perceptual equal-loudness compensation (k = 0.75): balances acoustic power with auditory masking
        let deltaDB = currentDB - refDB
        let compensationDB = -0.75 * deltaDB
        let compensationRatio = pow(10.0, compensationDB / 20.0)
        
        _cachedCompensationMultiplier = min(60.0, max(0.1, compensationRatio))
    }
    
    fileprivate func handleVolumeChange() {
        Logger.audio.debug("System output volume changed")
        recalculateCompensationMultiplier()
        NotificationCenter.default.post(
            name: .systemVolumeDidChange,
            object: nil
        )
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
        updateVolumeListener()
        recalculateCompensationMultiplier()
        NotificationCenter.default.post(
            name: .systemDefaultAudioDeviceDidChange,
            object: nil
        )
    }
    
    fileprivate func handleDeviceListChange() {
        Logger.audio.info("Audio device list changed, re-enumerating devices")
        enumerateAndCacheDevices()
        updateVolumeListener()
        recalculateCompensationMultiplier()
        NotificationCenter.default.post(
            name: .audioDeviceListDidChange,
            object: nil
        )
    }
    
    fileprivate func scheduleDeviceListChange() {
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleDeviceListChange()
        }
        
        workItemLock.lock()
        deviceListChangeWorkItem?.cancel()
        deviceListChangeWorkItem = workItem
        workItemLock.unlock()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: workItem)
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
    manager.scheduleDeviceListChange()
    
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

// MARK: - Callback for volume change

private func deviceVolumeChangedCallback(
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
        manager.handleVolumeChange()
    }
    
    return noErr
}

// MARK: - Notification Extension

extension Notification.Name {
    static let audioDeviceListDidChange = Notification.Name("audioDeviceListDidChange")
    static let systemDefaultAudioDeviceDidChange = Notification.Name("systemDefaultAudioDeviceDidChange")
}
