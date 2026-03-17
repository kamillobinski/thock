import Cocoa
import KeyboardShortcuts

class KeyboardEventTracker {
    private var pressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    private var lastEventTime: Double = 0
    
    deinit {
        stopTracking()
    }
    
    /// Starts tracking key events.
    /// - Parameter delegate: The delegate to handle key events.
    func startTracking() {
        stopTracking()
        
        let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue) |
        CGEventMask(1 << 14) // NSSystemDefined
        
        let observer = Unmanaged.passRetained(self).toOpaque()
        lastEventTime = currentTime()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                let tracker = Unmanaged<KeyboardEventTracker>.fromOpaque(userInfo!).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                if SettingsEngine.shared.isCleaningModeEnabled() {
                    if type == .keyDown,
                       let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCleaningMode),
                       let shortcutKey = shortcut.key {
                        let relevantFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                        let eventModifiers = event.flags.intersection(relevantFlags)
                        let shortcutModifiers = CGEventFlags(rawValue: UInt64(shortcut.modifiers.rawValue)).intersection(relevantFlags)
                        if keyCode == Int64(shortcutKey.rawValue), eventModifiers == shortcutModifiers {
                            DispatchQueue.main.async { SettingsEngine.shared.toggleCleaningMode() }
                        }
                    }
                    return nil
                }
                
                // Start latency measurement
                let latencyId = startLatencyMeasurement()
                recordLatencyCheckpoint(latencyId, point: .keyEventReceived)
                
                if SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled() {
                    // Ignore events that are too close to each other.
                    defer { tracker.lastEventTime = tracker.currentTime() }
                    let currentTimestamp = tracker.currentTime()
                    let elapsedTime = currentTimestamp - tracker.lastEventTime
                    if elapsedTime <= 10 { return Unmanaged.passUnretained(event) }
                }
                
                // Mute sound if music is playing and custom setting is enabled
                if AudioMonitor.shared.isMusicAppPlaying && SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
                    return Unmanaged.passUnretained(event)
                }
                
                defer {
                    switch type {
                    case .keyDown where !tracker.pressedKeys.contains(keyCode):
                        tracker.pressedKeys.insert(keyCode)
                        SoundEngine.shared.play(for: keyCode, isKeyDown: true, latencyId: latencyId)
                        
                    case .keyUp:
                        tracker.pressedKeys.remove(keyCode)
                        SoundEngine.shared.play(for: keyCode, isKeyDown: false, latencyId: latencyId)
                        
                    case .flagsChanged:
                        // Respect the user setting to ignore modifier key sounds
                        if !SettingsEngine.shared.isModifierKeySoundDisabled() {
                            if tracker.pressedKeys.remove(keyCode) == nil {
                                tracker.pressedKeys.insert(keyCode)
                                SoundEngine.shared.play(for: keyCode, isKeyDown: true, latencyId: latencyId)
                            } else {
                                SoundEngine.shared.play(for: keyCode, isKeyDown: false, latencyId: latencyId)
                            }
                        }
                    default:
                        break
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: observer
        )
        if let eventMonitor = eventMonitor {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventMonitor, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventMonitor, enable: true)
        } else {
            print("Failed to create event tap.")
        }
    }
    
    /// Stops tracking key events and removes the event tap.
    func stopTracking() {
        if let eventMonitor = eventMonitor {
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
    // MARK: Private methods
    
    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
    }
}
