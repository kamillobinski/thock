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
    
    @Test func playSoundWithSpatialPanDoesNotCrash() {
        let manager = SoundManager.shared
        
        // Should handle left, center, right pan without crashing
        manager.play(sound: "test.mp3", pan: -0.85, latencyId: nil)
        manager.play(sound: "test.mp3", pan: 0.0, latencyId: nil)
        manager.play(sound: "test.mp3", pan: 0.85, latencyId: nil)
    }
    
    // MARK: - Spatial Position Helper Tests
    
    @Test func spatialPositionKeyMapping() {
        // Left side keys should have negative pan
        let qPan = SpatialPositionHelper.panForKeyCode(12) // 'q'
        let aPan = SpatialPositionHelper.panForKeyCode(0)  // 'a'
        let tabPan = SpatialPositionHelper.panForKeyCode(48) // 'tab'
        #expect(qPan < 0.0)
        #expect(aPan < 0.0)
        #expect(tabPan < 0.0)
        
        // Center keys should be near 0
        let hPan = SpatialPositionHelper.panForKeyCode(4)  // 'h'
        let spacePan = SpatialPositionHelper.panForKeyCode(49) // 'space'
        #expect(abs(hPan) < 0.1)
        #expect(abs(spacePan) < 0.1)
        
        // Right side keys should have positive pan
        let enterPan = SpatialPositionHelper.panForKeyCode(36) // 'enter'
        let deletePan = SpatialPositionHelper.panForKeyCode(51) // 'del'
        #expect(enterPan > 0.0)
        #expect(deletePan > 0.0)
    }
    
    @Test func spatialGainCalculations() {
        // Zero spread should return equal gains of 1.0
        let monoGains = SpatialPositionHelper.calculateGains(pan: -0.8, spread: 0.0)
        #expect(monoGains.left == 1.0)
        #expect(monoGains.right == 1.0)
        
        // Center pan should have equal left and right gains
        let centerGains = SpatialPositionHelper.calculateGains(pan: 0.0, spread: 1.0)
        #expect(abs(centerGains.left - centerGains.right) < 0.01)
        
        // Left pan should have higher left gain than right gain
        let leftGains = SpatialPositionHelper.calculateGains(pan: -0.8, spread: 1.0)
        #expect(leftGains.left > leftGains.right)
        
        // Right pan should have higher right gain than left gain
        let rightGains = SpatialPositionHelper.calculateGains(pan: 0.8, spread: 1.0)
        #expect(rightGains.right > rightGains.left)
    }
    
    // MARK: - Spatial Audio Settings Tests
    
    @Test func spatialAudioSettingsToggle() {
        SettingsEngine.shared.setSpatialAudioEnabled(true)
        #expect(SettingsEngine.shared.isSpatialAudioEnabled() == true)
        
        SettingsEngine.shared.setSpatialAudioEnabled(false)
        #expect(SettingsEngine.shared.isSpatialAudioEnabled() == false)
        
        SettingsEngine.shared.setSpatialSpreadIntensity(0.5)
        #expect(abs(SettingsEngine.shared.getSpatialSpreadIntensity() - 0.5) < 0.01)
        
        SettingsEngine.shared.setMouseSpatialPosition(1.0)
        #expect(abs(SettingsEngine.shared.getMouseSpatialPosition() - 1.0) < 0.01)
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
                    manager.play(sound: "test.mp3", pan: Float.random(in: -1...1), latencyId: UUID())
                }
            }
        }
    }
}
