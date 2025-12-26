import Testing
import Foundation
@testable import Thock

struct SoundManagerTests {
    
    // MARK: - Volume Control Tests
    
    @Test func volumeStartsAtDefaultValue() {
        let manager = SoundManager.shared
        let volume = manager.getVolume()
        
        #expect(volume >= 0.0 && volume <= 1.0)
    }
    
    @Test func setVolumeWithinBounds() {
        let manager = SoundManager.shared
        
        manager.setVolume(0.7)
        #expect(manager.getVolume() == 0.7)
        
        manager.setVolume(0.3)
        #expect(manager.getVolume() == 0.3)
    }
    
    @Test func setVolumeClampsBelowZero() {
        let manager = SoundManager.shared
        
        manager.setVolume(-0.5)
        #expect(manager.getVolume() == 0.0)
    }
    
    @Test func setVolumeClampsAboveOne() {
        let manager = SoundManager.shared
        
        manager.setVolume(1.5)
        #expect(manager.getVolume() == 1.0)
    }
    
    @Test func setVolumeHandlesEdgeCases() {
        let manager = SoundManager.shared
        
        manager.setVolume(0.0)
        #expect(manager.getVolume() == 0.0)
        
        manager.setVolume(1.0)
        #expect(manager.getVolume() == 1.0)
    }
    
    // MARK: - Device Management Tests
    
    @Test func getCurrentOutputDeviceUIDReturnsString() {
        let manager = SoundManager.shared
        let deviceUID = manager.getCurrentOutputDeviceUID()
        
        #expect(!deviceUID.isEmpty)
    }
    
    @Test func applyPerDeviceVolumeDoesNotCrash() {
        let manager = SoundManager.shared
        
        // Should not crash even if no volume is saved
        manager.applyPerDeviceVolume()
        
        #expect(manager.getVolume() >= 0.0)
    }
    
    // MARK: - Sound Library Tests
    
    @Test func preloadSoundsWithValidMode() {
        let manager = SoundManager.shared
        let mode = Mode(
            id: UUID(),
            name: "Test Mode",
            isNew: false,
            path: "Sounds/Keyboard/Topre"
        )
        
        // Should not crash with valid mode
        manager.preloadSounds(for: mode)
        
        // Manager should remain ready
        #expect(manager.isReady == true)
    }
    
    @Test func preloadSoundsWithInvalidPathDoesNotCrash() {
        let manager = SoundManager.shared
        let mode = Mode(
            id: UUID(),
            name: "Invalid Mode",
            isNew: false,
            path: "NonExistent/Path"
        )
        
        // Should handle gracefully without crashing
        manager.preloadSounds(for: mode)
        
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
        let manager = SoundManager.shared
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let volume = Float(i % 10) / 10.0
                    manager.setVolume(volume)
                }
            }
        }
        
        let finalVolume = manager.getVolume()
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
