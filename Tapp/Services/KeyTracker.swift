//
//  KeyTracker.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa

class KeyTracker {
    private weak var delegate: KeyTrackerDelegate?
    private var pressedKeys: Set<Int64> = []
    private var eventMonitor: CFMachPort?
    
    init(delegate: KeyTrackerDelegate) {
        self.delegate = delegate
    }
    
    func startTrackingKeys() {
        stopTrackingKeys()
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventMonitor = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                
                let keyTracker = Unmanaged<KeyTracker>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                
                if type == .keyDown {
                    if keyTracker.pressedKeys.contains(keyCode) {
                        return Unmanaged.passUnretained(event)
                    }
                    keyTracker.pressedKeys.insert(keyCode)
                    keyTracker.delegate?.handleKeyDown(keyCode)
                } else if type == .keyUp {
                    keyTracker.pressedKeys.remove(keyCode)
                    keyTracker.delegate?.handleKeyUp(keyCode)
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
