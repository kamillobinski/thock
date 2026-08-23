import Testing
import Foundation
@testable import Thock

@Suite(.serialized)
struct SoundManagerTests {
    
    // MARK: - Volume Control Tests
    
    @Test func volumeStartsAtDefaultValue() {
        let volume = SettingsEngine.shared.getVolume()
        #expect(volume >= 0.0 && volume <= 1.0)
    }
    
    @Test func setVolumeWithinBounds() {
        SettingsEngine.shared.setVolume(0.7)
        #expect(abs(SettingsEngine.shared.getVolume() - 0.7) < 0.001)
        
        SettingsEngine.shared.setVolume(0.3)
        #expect(abs(SettingsEngine.shared.getVolume() - 0.3) < 0.001)
    }
    
    @Test func setVolumeClampsBelowZero() {
        SettingsEngine.shared.setVolume(-0.5)
        #expect(SettingsEngine.shared.getVolume() == 0.0)
    }
    
    @Test func setVolumeClampsAboveOne() {
        SettingsEngine.shared.setVolume(1.5)
        #expect(SettingsEngine.shared.getVolume() == 1.0)
    }
    
    @Test func setVolumeHandlesEdgeCases() {
        SettingsEngine.shared.setVolume(0.0)
        #expect(SettingsEngine.shared.getVolume() == 0.0)
        
        SettingsEngine.shared.setVolume(1.0)
        #expect(SettingsEngine.shared.getVolume() == 1.0)
    }
    
    // MARK: - Soundpack Loading Tests
    
    @Test func preloadSoundsWithValidSoundpack() {
        let manager = SoundManager.shared
        let soundpack = Soundpack(
            id: UUID(),
            name: "Test Soundpack",
            brand: "Custom",
            author: "Thock",
            category: "Linear",
            path: "Sounds/Keyboard/Topre"
        )
        
        // Should not crash with valid soundpack
        manager.preloadSounds(for: soundpack)
    }
    
    @Test func preloadSoundsWithInvalidPathDoesNotCrash() {
        let manager = SoundManager.shared
        let soundpack = Soundpack(
            id: UUID(),
            name: "Invalid Soundpack",
            brand: "Custom",
            author: "Thock",
            category: "Linear",
            path: "NonExistent/Path"
        )
        
        // Should handle gracefully without crashing
        manager.preloadSounds(for: soundpack)
    }
    
    // MARK: - Playback Tests
    
    @Test func playSoundWithNonexistentNameDoesNotCrash() {
        let manager = SoundManager.shared
        
        // Should log warning but not crash
        manager.play(sound: "nonexistent.mp3", latencyId: nil)
    }
    
    @Test func playSoundWithLatencyIdDoesNotCrash() {
        let manager = SoundManager.shared
        let latencyId = UUID()
        
        // Should handle latency tracking without crashing
        manager.play(sound: "test.mp3", latencyId: latencyId)
    }
    
    // MARK: - Auto Volume Compensation Settings Tests
    
    @Test func autoVolumeCompensationSettingsToggle() {
        SettingsEngine.shared.setAutoVolumeCompensation(true)
        #expect(SettingsEngine.shared.isAutoVolumeCompensationEnabled() == true)
        
        SettingsEngine.shared.setAutoVolumeCompensation(false)
        #expect(SettingsEngine.shared.isAutoVolumeCompensationEnabled() == false)
    }
    
    @Test func soundpackNormalizationSettingsToggle() {
        SettingsEngine.shared.setSoundpackNormalization(true)
        #expect(SettingsEngine.shared.isSoundpackNormalizationEnabled() == true)
        
        SettingsEngine.shared.setSoundpackNormalization(false)
        #expect(SettingsEngine.shared.isSoundpackNormalizationEnabled() == false)
    }
    
    // MARK: - Thread Safety Tests
    
    @Test func concurrentVolumeChangesAreSafe() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let volume = Float(i % 10) / 10.0
                    SettingsEngine.shared.setVolume(volume)
                }
            }
        }
        
        let finalVolume = SettingsEngine.shared.getVolume()
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
    }
}
