//
//  KeyTracker.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa

class KeyTracker {
    private weak var delegate: KeyTrackerDelegate?
    private var pressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    
    init(delegate: KeyTrackerDelegate? = nil) {
        self.delegate = delegate
    }
    
    deinit {
        stopTrackingKeys()
    }
    
    /// Starts tracking key events.
    /// - Parameter delegate: The delegate to handle key events.
    func startTrackingKeys(delegate: KeyTrackerDelegate? = nil) {
        stopTrackingKeys()
        
        if let delegate = delegate {
            self.delegate = delegate
        }
        
        let eventMask: CGEventMask =
        (1 << CGEventType.keyDown.rawValue) |
        (1 << CGEventType.keyUp.rawValue) |
        (1 << CGEventType.flagsChanged.rawValue)
        
        let observer = Unmanaged.passRetained(self).toOpaque()
        
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                let keyTracker = Unmanaged<KeyTracker>.fromOpaque(userInfo!).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                switch type {
                case .keyDown where !keyTracker.pressedKeys.contains(keyCode):
                    keyTracker.pressedKeys.insert(keyCode)
                    keyTracker.delegate?.handleKeyDown(keyCode)
                    
                case .keyUp:
                    keyTracker.pressedKeys.remove(keyCode)
                    keyTracker.delegate?.handleKeyUp(keyCode)
                    
                case .flagsChanged:
                    if keyTracker.pressedKeys.remove(keyCode) == nil {
                        keyTracker.pressedKeys.insert(keyCode)
                        keyTracker.delegate?.handleKeyDown(keyCode)
                    } else {
                        keyTracker.delegate?.handleKeyUp(keyCode)
                    }
                    
                default:
                    break
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
    func stopTrackingKeys() {
        if let eventMonitor = eventMonitor {
            CFMachPortInvalidate(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

protocol KeyTrackerDelegate: AnyObject {
    func handleKeyDown(_ keyCode: Int64)
    func handleKeyUp(_ keyCode: Int64)
}
