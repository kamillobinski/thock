import Cocoa

/// Tracks trackpad/mouse click events and plays sounds.
class TrackpadTracker {
    private var eventMonitor: CFMachPort?
    private var settingsObserver: NSObjectProtocol?
    
    init() {
        // Observe settings changes to start/stop tracking dynamically
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChange()
        }
    }
    
    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopTracking()
    }
    
    /// Starts tracking if trackpad sound is enabled, otherwise stops.
    func startTrackingIfEnabled() {
        if SettingsEngine.shared.isTrackpadSoundEnabled() {
            startTracking()
        } else {
            stopTracking()
        }
    }
    
    /// Handles settings changes to start/stop tracking dynamically.
    private func handleSettingsChange() {
        startTrackingIfEnabled()
    }
    
    /// Starts tracking trackpad click events.
    private func startTracking() {
        // Already tracking
        guard eventMonitor == nil else { return }
        
        // Only track left mouse down (trackpad click)
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        // Use passUnretained to avoid retain cycle - the tracker's lifetime is managed by AppDelegate
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                // Don't play if app is disabled
                guard AppEngine.shared.isEnabled() else {
                    return Unmanaged.passUnretained(event)
                }
                
                // Mute if music is playing and auto-mute is enabled
                if AudioMonitor.shared.isMusicAppPlaying && SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
                    return Unmanaged.passUnretained(event)
                }
                
                // Play trackpad click sound
                if type == .leftMouseDown {
                    SoundManager.shared.playTrackpadClick()
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
            print("Failed to create trackpad event tap.")
        }
    }
    
    /// Stops tracking trackpad click events.
    func stopTracking() {
        if let eventMonitor = eventMonitor {
            CGEvent.tapEnable(tap: eventMonitor, enable: false)
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
