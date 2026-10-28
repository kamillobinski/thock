import Cocoa
import OSLog
import KeyboardShortcuts

class KeyboardEventTracker {
    private var pressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trackedRunLoop: CFRunLoop?
    private var lastEventTime: Double = 0
    private var tapReEnableCount = 0
    
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
        
        // AppDelegate owns the tracker and stops the tap before releasing it.
        let observer = Unmanaged.passUnretained(self).toOpaque()
        lastEventTime = currentTime()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<KeyboardEventTracker>.fromOpaque(userInfo).takeUnretainedValue()
                
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    tracker.reenableTap()
                    return Unmanaged.passUnretained(event)
                }
                
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                if SettingsEngine.shared.isCleaningModeEnabled() {
                    if type == .keyDown,
                       let shortcut = KeyboardShortcuts.getShortcut(for: .toggleCleaningMode),
                       let shortcutKey = shortcut.key {
                        let relevantFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                        let eventModifiers = event.flags.intersection(relevantFlags)
                        let shortcutModifiers = CGEventFlags(rawValue: UInt64(shortcut.modifiers.rawValue)).intersection(relevantFlags)
                        if keyCode == Int64(shortcutKey.rawValue), eventModifiers == shortcutModifiers {
                            SettingsEngine.shared.toggleCleaningMode()
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
                
                let soundAction: (keyCode: Int64, isKeyDown: Bool)?
                switch type {
                case .keyDown where !tracker.pressedKeys.contains(keyCode):
                    tracker.pressedKeys.insert(keyCode)
                    soundAction = (keyCode, true)
                    
                case .keyUp:
                    tracker.pressedKeys.remove(keyCode)
                    soundAction = (keyCode, false)
                    
                case .flagsChanged:
                    // Respect the user setting to ignore modifier key sounds
                    if !SettingsEngine.shared.isModifierKeySoundDisabled() {
                        // Event flags survive missed transitions. Side-specific masks
                        // also distinguish releases while the opposite key stays held.
                        let modifierMask: CGEventFlags
                        switch keyCode {
                        case 54: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK))
                        case 55: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK))
                        case 56: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK))
                        case 57: modifierMask = .maskAlphaShift
                        case 58: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
                        case 59: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))
                        case 60: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK))
                        case 61: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
                        case 62: modifierMask = CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))
                        case 63: modifierMask = .maskSecondaryFn
                        default: return Unmanaged.passUnretained(event)
                        }
                        soundAction = (keyCode, event.flags.contains(modifierMask))
                    } else {
                        soundAction = nil
                    }
                    
                default:
                    soundAction = nil
                }
                
                if let action = soundAction {
                    // The tap runs on the main run loop. Capture this event's keyboard before
                    // another device can type and before leaving Carbon's supported thread.
                    let layout = KeyLayout.Physical.fromKeyboardType(event.getIntegerValueField(.keyboardEventKeyboardType))
                    SoundManager.playbackQueue.async {
                        SoundEngine.shared.play(for: action.keyCode, isKeyDown: action.isKeyDown, layout: layout, latencyId: latencyId)
                    }
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: observer
        )
        if let eventMonitor = eventMonitor {
            let runLoop = CFRunLoopGetCurrent()
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventMonitor, 0)
            CFRunLoopAddSource(runLoop, source, .commonModes)
            runLoopSource = source
            trackedRunLoop = runLoop
            CGEvent.tapEnable(tap: eventMonitor, enable: true)
        } else {
            Logger.keyboard.error("Failed to create event tap")
        }
    }
    
    /// Stops tracking key events and releases the event tap and its run loop source.
    func stopTracking() {
        if let eventMonitor = eventMonitor {
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }

        // Remove the source from the run loop that registered it.
        if let source = runLoopSource, let runLoop = trackedRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        pressedKeys.removeAll()
        runLoopSource = nil
        trackedRunLoop = nil
    }
    
    // MARK: Private methods

    /// Re-enables the tap after the system disabled it.
    private func reenableTap() {
        guard let eventMonitor = eventMonitor else { return }
        pressedKeys.removeAll() // Key-up events may have been missed while disabled.
        CGEvent.tapEnable(tap: eventMonitor, enable: true)
        tapReEnableCount += 1
        Logger.keyboard.warning("Event tap was disabled by the system and re-enabled (re-enable #\(self.tapReEnableCount))")
    }
    
    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
    }
}
