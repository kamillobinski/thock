import Cocoa

/// Represents a mouse button event type for sound playback.
enum MouseButtonEvent: Hashable, CustomStringConvertible {
    case leftDown
    case leftUp
    case rightDown
    case rightUp
    
    var description: String {
        switch self {
        case .leftDown: return "leftDown"
        case .leftUp: return "leftUp"
        case .rightDown: return "rightDown"
        case .rightUp: return "rightUp"
        }
    }
}

/// Tracks mouse button events and plays sounds.
class MouseEventTracker {
    private var eventMonitor: CFMachPort?
    private var settingsObserver: NSObjectProtocol?
    
    init() {
        // Observe mouse sound setting changes to start/stop tracking dynamically
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .mouseSoundDidChange,
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
    
    /// Starts tracking if enabled, otherwise stops.
    func startTrackingIfEnabled() {
        if SettingsEngine.shared.isMouseSoundEnabled() {
            startTracking()
        } else {
            stopTracking()
        }
    }
    
    /// Handles settings changes to start/stop tracking dynamically.
    private func handleSettingsChange() {
        startTrackingIfEnabled()
    }
    
    /// Starts tracking mouse button events.
    private func startTracking() {
        // Already tracking
        guard eventMonitor == nil else { return }
        
        // Track all mouse button events: left down/up, right down/up
        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) |
        (1 << CGEventType.leftMouseUp.rawValue) |
        (1 << CGEventType.rightMouseDown.rawValue) |
        (1 << CGEventType.rightMouseUp.rawValue)
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, _ in
                // Don't play if app is disabled
                guard AppEngine.shared.isEnabled() else {
                    return Unmanaged.passUnretained(event)
                }
                
                // Mute if music is playing and auto-mute is enabled
                if AudioMonitor.shared.isMusicAppPlaying && SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
                    return Unmanaged.passUnretained(event)
                }
                
                // Map CGEventType to MouseButtonEvent and play sound
                let mouseEvent: MouseButtonEvent?
                switch type {
                case .leftMouseDown:
                    mouseEvent = .leftDown
                case .leftMouseUp:
                    mouseEvent = .leftUp
                case .rightMouseDown:
                    mouseEvent = .rightDown
                case .rightMouseUp:
                    mouseEvent = .rightUp
                default:
                    mouseEvent = nil
                }
                
                if let mouseEvent = mouseEvent {
                    SoundManager.shared.playMouseSound(for: mouseEvent)
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        
        if let eventMonitor = eventMonitor {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventMonitor, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventMonitor, enable: true)
        } else {
            print("Failed to create mouse event tap.")
        }
    }
    
    /// Stops tracking mouse button events.
    func stopTracking() {
        if let eventMonitor = eventMonitor {
            CGEvent.tapEnable(tap: eventMonitor, enable: false)
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
