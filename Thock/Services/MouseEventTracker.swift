import Cocoa
import OSLog

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
    private var runLoopSource: CFRunLoopSource?
    private var trackedRunLoop: CFRunLoop?
    private var settingsObserver: NSObjectProtocol?
    private var tapReEnableCount = 0
    
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
        
        // Pass an unretained pointer: AppDelegate owns this tracker and calls
        // stopTracking() before releasing it, so the tap never outlives the object.
        let observer = Unmanaged.passUnretained(self).toOpaque()

        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<MouseEventTracker>.fromOpaque(userInfo).takeUnretainedValue()

                // Re-enable rather than ignore: a tap disabled by the system stayed
                // disabled for the rest of the process lifetime, so mouse clicks went
                // silent until the app was relaunched.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    tracker.reenableTap()
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
                    // Read before the hop, the event is only valid inside the tap callback
                    let location = event.location
                    SoundManager.playbackQueue.async { SoundManager.shared.playMouseSound(for: mouseEvent, location: location) }
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
            Logger.lifecycle.error("Failed to create mouse event tap")
        }
    }
    
    /// Stops tracking mouse button events and releases the tap and its run loop source.
    func stopTracking() {
        if let eventMonitor = eventMonitor {
            CGEvent.tapEnable(tap: eventMonitor, enable: false)
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }

        // Remove the source from the run loop it was registered on. Leaving it behind
        // accumulated a source every time tracking was restarted.
        if let source = runLoopSource, let runLoop = trackedRunLoop {
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
        }
        runLoopSource = nil
        trackedRunLoop = nil
    }

    // MARK: Private methods

    /// Re-enables the tap after the system disabled it.
    private func reenableTap() {
        guard let eventMonitor = eventMonitor else { return }
        CGEvent.tapEnable(tap: eventMonitor, enable: true)
        tapReEnableCount += 1
        Logger.lifecycle.warning("Mouse event tap was disabled by the system and re-enabled (re-enable #\(self.tapReEnableCount))")
    }
}
