import Cocoa

/// Tracks trackpad/mouse click events and plays sounds.
class TrackpadTracker {
    private var eventMonitor: CFMachPort?
    
    deinit {
        stopTracking()
    }
    
    /// Starts tracking trackpad click events.
    func startTracking() {
        stopTracking()
        
        // Only track left mouse down (trackpad click)
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
        
        let observer = Unmanaged.passRetained(self).toOpaque()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                // Check if trackpad sound is enabled
                guard SettingsEngine.shared.isTrackpadSoundEnabled() else {
                    return Unmanaged.passUnretained(event)
                }
                
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
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
