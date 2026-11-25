import Cocoa
import OSLog
import KeyboardShortcuts

class KeyboardEventTracker {
    private var pressedKeys: Set<Int64> = []
    /// Held-key state for the visual overlay path, tracked separately so
    /// sound-related filters (rapid-event filter, music auto-mute, cleaning
    /// mode) can never leave it stale.
    private var visualPressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trackedRunLoop: CFRunLoop?
    private var lastEventTime: Double = 0
    private var tapReEnableCount = 0
    
    /// Receives every key transition (keyCode, isKeyDown) for visual display,
    /// independent of sound-related settings. Invoked on the tap's run loop (main).
    var onKeyVisualEvent: ((_ keyCode: Int64, _ isKeyDown: Bool) -> Void)?

    /// Invoked when the tracker drops its held-key state (tap re-enable,
    /// stop tracking): overlays should clear any held-key visuals.
    var onKeyVisualReset: (() -> Void)?
    
    private var cleaningModeObserver: NSObjectProtocol?
    private var tapIsActive = false

    init() {
        cleaningModeObserver = NotificationCenter.default.addObserver(forName: .cleaningModeDidChange, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.eventMonitor != nil else { return }
                if SettingsEngine.shared.isCleaningModeEnabled() != self.tapIsActive {
                    self.startTracking()
                }
            }
        }
    }

    deinit {
        if let cleaningModeObserver { NotificationCenter.default.removeObserver(cleaningModeObserver) }
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
        tapIsActive = SettingsEngine.shared.isCleaningModeEnabled()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: tapIsActive ? .defaultTap : .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<KeyboardEventTracker>.fromOpaque(userInfo).takeUnretainedValue()
                
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    tracker.reenableTap()
                    return Unmanaged.passUnretained(event)
                }
                
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                // Forward the transition to the key overlay first, regardless of
                // any sound-related filtering below — cleaning mode included, so
                // releases swallowed there can never leave a key stuck lit.
                if let onKeyVisualEvent = tracker.onKeyVisualEvent {
                    switch type {
                    case .keyDown where !tracker.visualPressedKeys.contains(keyCode):
                        tracker.visualPressedKeys.insert(keyCode)
                        onKeyVisualEvent(keyCode, true)
                    case .keyUp:
                        tracker.visualPressedKeys.remove(keyCode)
                        onKeyVisualEvent(keyCode, false)
                    case .flagsChanged:
                        if let mask = tracker.modifierMask(for: keyCode) {
                            onKeyVisualEvent(keyCode, event.flags.contains(mask))
                        }
                    default:
                        break
                    }
                }
                
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
                        guard let modifierMask = tracker.modifierMask(for: keyCode) else {
                            return Unmanaged.passUnretained(event)
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
        visualPressedKeys.removeAll()
        runLoopSource = nil
        trackedRunLoop = nil
        DispatchQueue.main.async { [weak self] in self?.onKeyVisualReset?() }
    }
    
    // MARK: Private methods

    /// Maps a modifier key code to the event flag that reports its pressed state.
    func modifierMask(for keyCode: Int64) -> CGEventFlags? {
        switch keyCode {
        case 54: return CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK))
        case 55: return CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK))
        case 56: return CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK))
        case 57: return .maskAlphaShift
        case 58: return CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
        case 59: return CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))
        case 60: return CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK))
        case 61: return CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
        case 62: return CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))
        case 63: return .maskSecondaryFn
        default: return nil
        }
    }
    
    /// Re-enables the tap after the system disabled it.
    private func reenableTap() {
        guard let eventMonitor = eventMonitor else { return }
        pressedKeys.removeAll() // Key-up events may have been missed while disabled.
        visualPressedKeys.removeAll()
        onKeyVisualReset?()
        CGEvent.tapEnable(tap: eventMonitor, enable: true)
        tapReEnableCount += 1
        Logger.keyboard.warning("Event tap was disabled by the system and re-enabled (re-enable #\(self.tapReEnableCount))")
    }
    
    private func currentTime() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000
    }
}
