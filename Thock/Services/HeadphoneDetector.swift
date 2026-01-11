import Foundation
import CoreAudio
import OSLog

/// Detects when headphones (Bluetooth or wired via 3.5mm jack) are connected/disconnected
/// and automatically enables/disables Thock accordingly.
final class HeadphoneDetector {
    static let shared = HeadphoneDetector()
    
    private var isMonitoring = false
    private var jackListenerAddress: AudioObjectPropertyAddress?
    private var defaultDeviceID: AudioDeviceID = 0
    
    private init() {}
    
    // MARK: - Public API
    
    /// Starts monitoring for headphone connections (Bluetooth and wired).
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Monitor Bluetooth device list changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceListChange),
            name: .audioDeviceListDidChange,
            object: nil
        )
        
        // Monitor default device changes (for jack detection)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDefaultDeviceChange),
            name: .systemDefaultAudioDeviceDidChange,
            object: nil
        )
        
        // Setup jack listener for wired headphones
        setupJackListener()
        
        isMonitoring = true
        Logger.audio.info("HeadphoneDetector: Started monitoring for headphones")
        
        // Check initial state on app launch
        applyInitialState()
    }
    
    /// Applies initial app state based on headphone connection when app launches.
    private func applyInitialState() {
        guard SettingsEngine.shared.isAutoEnableOnHeadphoneEnabled() else { return }
        
        let headphoneConnected = isHeadphoneConnected()
        Logger.audio.info("HeadphoneDetector: Initial check - headphone connected: \(headphoneConnected)")
        
        // Set app state based on headphone connection
        AppEngine.shared.setEnabled(headphoneConnected)
    }
    
    /// Stops monitoring for device changes.
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        NotificationCenter.default.removeObserver(self, name: .audioDeviceListDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .systemDefaultAudioDeviceDidChange, object: nil)
        
        removeJackListener()
        
        isMonitoring = false
        Logger.audio.info("HeadphoneDetector: Stopped monitoring")
    }
    
    /// Checks if any headphone (Bluetooth or wired) is currently connected.
    func isHeadphoneConnected() -> Bool {
        return isBluetoothHeadphoneConnected() || isWiredHeadphoneConnected()
    }
    
    // MARK: - Bluetooth Detection
    
    /// Checks if any Bluetooth audio output device is currently connected.
    private func isBluetoothHeadphoneConnected() -> Bool {
        let devices = AudioDeviceManager.shared.getAvailableOutputDevices()
        
        for device in devices {
            guard device.deviceID != 0 else { continue }
            
            if let transportType = getTransportType(for: device.deviceID) {
                if transportType == kAudioDeviceTransportTypeBluetooth ||
                   transportType == kAudioDeviceTransportTypeBluetoothLE {
                    Logger.audio.debug("HeadphoneDetector: Found Bluetooth device: \(device.name)")
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Wired Headphone Detection (3.5mm Jack)
    
    /// Checks if wired headphones are connected via the 3.5mm jack.
    private func isWiredHeadphoneConnected() -> Bool {
        let devices = AudioDeviceManager.shared.getAvailableOutputDevices()
        
        for device in devices {
            guard device.deviceID != 0 else { continue }
            
            // Check if device name contains "Headphone" (e.g., "BuiltInHeadphoneOutputDevice")
            let nameLower = device.name.lowercased()
            if nameLower.contains("headphone") || nameLower.contains("耳机") {
                Logger.audio.debug("HeadphoneDetector: Found wired headphone device: \(device.name)")
                return true
            }
            
            // Also check Jack connection for built-in device
            if let transportType = getTransportType(for: device.deviceID),
               transportType == kAudioDeviceTransportTypeBuiltIn {
                if isJackConnected(deviceID: device.deviceID) {
                    Logger.audio.debug("HeadphoneDetector: Wired headphone detected via jack on \(device.name)")
                    return true
                }
            }
        }
        return false
    }
    
    /// Gets the built-in output device ID.
    private func getBuiltInOutputDeviceID() -> AudioDeviceID? {
        let devices = AudioDeviceManager.shared.getAvailableOutputDevices()
        
        for device in devices {
            guard device.deviceID != 0 else { continue }
            
            if let transportType = getTransportType(for: device.deviceID),
               transportType == kAudioDeviceTransportTypeBuiltIn {
                return device.deviceID
            }
        }
        return nil
    }
    
    /// Checks if a jack is connected to the given device.
    private func isJackConnected(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyJackIsConnected,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Check if property exists
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }
        
        var isConnected: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &isConnected
        )
        
        if status == noErr && isConnected == 1 {
            Logger.audio.debug("HeadphoneDetector: Wired headphones detected via jack")
            return true
        }
        return false
    }
    
    /// Sets up a listener for jack connection changes.
    private func setupJackListener() {
        guard let deviceID = getBuiltInOutputDeviceID() else { return }
        
        defaultDeviceID = deviceID
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyJackIsConnected,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }
        
        let status = AudioObjectAddPropertyListener(
            deviceID,
            &propertyAddress,
            jackConnectionChangedCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        if status == noErr {
            jackListenerAddress = propertyAddress
            Logger.audio.debug("HeadphoneDetector: Jack listener added for device \(deviceID)")
        }
    }
    
    /// Removes the jack connection listener.
    private func removeJackListener() {
        guard let address = jackListenerAddress, defaultDeviceID != 0 else { return }
        
        var mutableAddress = address
        AudioObjectRemovePropertyListener(
            defaultDeviceID,
            &mutableAddress,
            jackConnectionChangedCallback,
            Unmanaged.passUnretained(self).toOpaque()
        )
        
        jackListenerAddress = nil
        defaultDeviceID = 0
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleDeviceListChange() {
        checkAndUpdateState()
    }
    
    @objc private func handleDefaultDeviceChange() {
        // Re-setup jack listener when default device changes
        removeJackListener()
        setupJackListener()
        checkAndUpdateState()
    }
    
    fileprivate func handleJackConnectionChange() {
        DispatchQueue.main.async {
            self.checkAndUpdateState()
        }
    }
    
    private func checkAndUpdateState() {
        guard SettingsEngine.shared.isAutoEnableOnHeadphoneEnabled() else { return }
        
        if isHeadphoneConnected() {
            handleHeadphoneConnected()
        } else {
            handleHeadphoneDisconnected()
        }
    }
    
    private func handleHeadphoneConnected() {
        guard SettingsEngine.shared.isAutoEnableOnHeadphoneEnabled() else { return }
        
        if !AppEngine.shared.isEnabled() {
            Logger.audio.info("HeadphoneDetector: Headphone connected, enabling Thock")
            AppEngine.shared.setEnabled(true)
        }
    }
    
    private func handleHeadphoneDisconnected() {
        guard SettingsEngine.shared.isAutoEnableOnHeadphoneEnabled() else { return }
        
        if AppEngine.shared.isEnabled() {
            Logger.audio.info("HeadphoneDetector: Headphone disconnected, disabling Thock")
            AppEngine.shared.setEnabled(false)
        }
    }
    
    // MARK: - Helpers
    
    private func getTransportType(for deviceID: AudioDeviceID) -> UInt32? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &transportType
        )
        
        return status == noErr ? transportType : nil
    }
}

// MARK: - Jack Connection Callback

private func jackConnectionChangedCallback(
    _ inObjectID: AudioObjectID,
    _ inNumberAddresses: UInt32,
    _ inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = inClientData else { return noErr }
    
    let detector = Unmanaged<HeadphoneDetector>.fromOpaque(clientData).takeUnretainedValue()
    detector.handleJackConnectionChange()
    
    return noErr
}
