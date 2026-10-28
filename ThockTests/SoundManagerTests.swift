import Testing
import Foundation
import CoreAudio
@testable import Thock

@Suite(.serialized)
struct SoundManagerTests {
    
    // MARK: - Volume Control Tests
    
    // Uses a dedicated device UID so tests never touch the user's real per-device volume
    private let testDeviceUID = "thock-tests-device"
    
    private func removeTestVolume() {
        SettingsManager.shared.perDeviceVolumes.removeValue(forKey: testDeviceUID)
    }
    
    @Test func volumeDefaultsToHalfForUnknownDevice() {
        #expect(SettingsEngine.shared.getVolume(for: "thock-tests-unknown-device") == 0.5)
    }
    
    @Test func setVolumeWithinBounds() {
        defer { removeTestVolume() }
        SettingsEngine.shared.setVolume(0.7, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 0.7)
        
        SettingsEngine.shared.setVolume(0.3, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 0.3)
    }
    
    @Test func setVolumeClampsBelowZero() {
        defer { removeTestVolume() }
        SettingsEngine.shared.setVolume(-0.5, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 0.0)
    }
    
    @Test func setVolumeClampsAboveOne() {
        defer { removeTestVolume() }
        SettingsEngine.shared.setVolume(1.5, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 1.0)
    }

    @Test func setVolumeHandlesEdgeCases() {
        defer { removeTestVolume() }
        SettingsEngine.shared.setVolume(0.0, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 0.0)

        SettingsEngine.shared.setVolume(1.0, for: testDeviceUID)
        #expect(SettingsEngine.shared.getVolume(for: testDeviceUID) == 1.0)
    }
    
    // MARK: - Device Management Tests
    
    @Test func getCurrentOutputDeviceUIDReturnsString() {
        let manager = SoundManager.shared
        let deviceUID = manager.getCurrentOutputDeviceUID()
        
        #expect(!deviceUID.isEmpty)
    }
    
    // MARK: - Sound Library Tests

    @Test(.enabled(if: SoundpackManager.shared.getCurrentKeyboardSoundpack() != nil, "No keyboard soundpack installed"))
    func preloadSoundsWithInstalledSoundpack() throws {
        let manager = SoundManager.shared
        let soundpack = try #require(SoundpackManager.shared.getCurrentKeyboardSoundpack())

        // Should not crash with a valid soundpack
        manager.preloadSounds(for: soundpack)

        // Manager should remain ready
        #expect(manager.isReady == true)
    }

    @Test func preloadSoundsWithInvalidPathDoesNotCrash() {
        let manager = SoundManager.shared
        let soundpack = Soundpack(
            id: UUID(),
            name: "Invalid Soundpack",
            brand: "",
            author: "",
            category: "keyboard",
            path: "NonExistent/Path"
        )

        // Should handle gracefully without crashing
        manager.preloadSounds(for: soundpack)

        #expect(manager.isReady == true)
    }

    // MARK: - Playback Tests
    
    @Test func playSoundWithNonexistentNameDoesNotCrash() {
        let manager = SoundManager.shared
        
        // Should log warning but not crash
        manager.play(sound: "nonexistent.mp3", latencyId: nil)
        #expect(manager.isReady == true)
    }
    
    @Test func playSoundWithLatencyIdDoesNotCrash() {
        let manager = SoundManager.shared
        let latencyId = UUID()
        
        // Should handle latency tracking without crashing
        manager.play(sound: "test.mp3", latencyId: latencyId)
        #expect(manager.isReady == true)
    }
    
    // MARK: - Initialization Tests
    
    @Test func managerInitializesSuccessfully() {
        let manager = SoundManager.shared
        #expect(manager.isReady == true)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test func concurrentVolumeChangesAreSafe() async {
        defer { removeTestVolume() }
        let uid = testDeviceUID
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    SettingsEngine.shared.setVolume(Float(i % 10) / 10.0, for: uid)
                }
            }
        }
        
        let finalVolume = SettingsEngine.shared.getVolume(for: uid)
        #expect(finalVolume >= 0.0 && finalVolume <= 1.0)
    }
    
    @Test func concurrentPlayCallsAreSafe() async {
        let manager = SoundManager.shared
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    manager.play(sound: "test.mp3", latencyId: UUID())
                }
            }
        }
        #expect(manager.isReady == true)
    }
}

@Suite(.serialized)
struct OutputKindMonitorTests {
    @Test func routedDeviceAndStreamChangesRefreshClassification() throws {
        let properties = OutputKindProperties()
        properties.streams = [10: [101]]
        var refreshes = 0
        let monitor = properties.monitor { refreshes += 1 }
        monitor.update(deviceID: 10)

        for selector in [kAudioDevicePropertyPreferredChannelsForStereo, kAudioDevicePropertyDataSource,
                         kAudioDevicePropertyJackIsConnected, kAudioDevicePropertyStreams] {
            let before = refreshes
            try properties.send(object: 10, selector: selector)
            #expect(refreshes == before + 1)
        }
        for selector in [kAudioStreamPropertyTerminalType, kAudioStreamPropertyStartingChannel,
                         kAudioStreamPropertyVirtualFormat] {
            let before = refreshes
            try properties.send(object: 101, selector: selector)
            #expect(refreshes == before + 1)
        }
    }

    @Test func streamReplacementObservesNewStreamsAndIgnoresOldCallbacks() throws {
        let properties = OutputKindProperties()
        properties.streams = [10: [101]]
        var refreshes = 0
        let monitor = properties.monitor { refreshes += 1 }
        monitor.update(deviceID: 10)
        let oldCallback = try properties.callback(object: 101, selector: kAudioStreamPropertyTerminalType)

        properties.streams[10] = [102]
        try properties.send(object: 10, selector: kAudioDevicePropertyStreams)
        let afterReplacement = refreshes
        properties.invoke(oldCallback)
        #expect(refreshes == afterReplacement)
        try properties.send(object: 102, selector: kAudioStreamPropertyTerminalType)
        #expect(refreshes == afterReplacement + 1)
        #expect(!properties.registrations.values.contains { $0.object == 101 })
    }

    @Test func routeChangeAndStopIgnoreAlreadyQueuedCallbacks() throws {
        let properties = OutputKindProperties()
        properties.streams = [10: [101], 20: [201]]
        var refreshes = 0
        let monitor = properties.monitor { refreshes += 1 }
        monitor.update(deviceID: 10)
        let oldCallback = try properties.callback(object: 10, selector: kAudioDevicePropertyDataSource)
        monitor.update(deviceID: 20)
        properties.invoke(oldCallback)
        #expect(refreshes == 0)
        #expect(!properties.registrations.values.contains { $0.object == 10 || $0.object == 101 })

        let currentCallback = try properties.callback(object: 20, selector: kAudioDevicePropertyDataSource)
        monitor.update(deviceID: nil)
        properties.invoke(currentCallback)
        #expect(refreshes == 0)
        #expect(properties.registrations.isEmpty)
    }
}

private final class OutputKindProperties {
    struct Registration {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        let callback: AudioObjectPropertyListenerBlock
    }
    var streams: [AudioDeviceID: [AudioStreamID]] = [:]
    var registrations: [String: Registration] = [:]

    func monitor(onChange: @escaping () -> Void) -> OutputKindMonitor {
        OutputKindMonitor(streamIDs: { [self] in streams[$0] ?? [] },
                          addListener: { [self] object, address, callback in
                              registrations[key(object, address)] = Registration(object: object, address: address, callback: callback)
                              return noErr
                          },
                          removeListener: { [self] object, address, _ in
                              registrations.removeValue(forKey: key(object, address))
                          }, onChange: onChange)
    }

    func callback(object: AudioObjectID, selector: AudioObjectPropertySelector) throws -> AudioObjectPropertyListenerBlock {
        try #require(registrations.values.first { $0.object == object && $0.address.mSelector == selector }?.callback)
    }

    func send(object: AudioObjectID, selector: AudioObjectPropertySelector) throws {
        invoke(try callback(object: object, selector: selector))
    }

    func invoke(_ callback: AudioObjectPropertyListenerBlock) {
        var address = AudioObjectPropertyAddress()
        withUnsafePointer(to: &address) { callback(1, $0) }
    }

    private func key(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String {
        "\(object)-\(address.mSelector)-\(address.mScope)-\(address.mElement)"
    }
}
