//
//  KeyTracker.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa

class KeyTracker {
    private var pressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    
    deinit {
        stopTrackingKeys()
    }
    
    /// Starts tracking key events.
    /// - Parameter delegate: The delegate to handle key events.
    func startTrackingKeys() {
        stopTrackingKeys()
        
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
                    SoundManager.shared.playSound(for: keyCode, isKeyDown: true)
                    
                case .keyUp:
                    keyTracker.pressedKeys.remove(keyCode)
                    SoundManager.shared.playSound(for: keyCode, isKeyDown: false)
                    
                case .flagsChanged:
                    if keyTracker.pressedKeys.remove(keyCode) == nil {
                        keyTracker.pressedKeys.insert(keyCode)
                        SoundManager.shared.playSound(for: keyCode, isKeyDown: true)
                    } else {
                        SoundManager.shared.playSound(for: keyCode, isKeyDown: false)
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
