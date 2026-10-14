import Testing
import Foundation
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
