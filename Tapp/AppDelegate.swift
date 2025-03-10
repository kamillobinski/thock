//
//  AppDelegate.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, KeyTrackerDelegate, MenuManagerDelegate {
    var statusBarItem: NSStatusItem!
    var menuManager: MenuManager!
    var isEnabled: Bool = true
    var keyTracker: KeyTracker!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isProcessTrusted() else {
            exit(1)
        }
        keyTracker = KeyTracker(delegate: self)
        keyTracker.startTrackingKeys()
        SoundConfigManager.shared.loadConfig()
        
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        menuManager = MenuManager(statusBarItem: statusBarItem, delegate: self)
        menuManager.updateMenuBarIcon()
    }
    
    func isProcessTrusted() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
    
    func handleKeyDown(_ keyCode: Int64) {
        guard isEnabled else { return }
        
        let keyType = KeyType.fromKeyCode(keyCode)
        let soundList = SoundConfigManager.shared.getKeyDownSounds(for: keyType)
        
        if let soundFileName = soundList.randomElement() {
            SoundManager.shared.playSound(soundFileName: soundFileName, mode: SoundModeManager.shared.getMode())
        } else {
            print("Warning: No available sound for keyCode: \(keyCode)")
        }
    }
    
    func handleKeyUp(_ keyCode: Int64) {
        guard isEnabled else { return }
        
        let keyType = KeyType.fromKeyCode(keyCode)
        let soundList = SoundConfigManager.shared.getKeyUpSounds(for: keyType)
        
        if let soundFileName = soundList.randomElement() {
            SoundManager.shared.playSound(soundFileName: soundFileName, mode: SoundModeManager.shared.getMode())
        } else {
            print("Warning: No available sound for keyCode: \(keyCode)")
        }
    }
    
    var isSoundEnabled: Bool { return isEnabled }
    
    func toggleSound() {
        isEnabled.toggle()
        menuManager.updateMenuBarIcon()
    }
    
    func changeMode(to mode: String) {
        SoundManager.shared.clearAudioDataCache()
        if let newType = Modes.fromDisplayName(mode) {
            SoundModeManager.shared.setMode(newType)
            SoundConfigManager.shared.loadConfig()
        }
    }
    
    func quitApp() {
        keyTracker.stopTrackingKeys()
        NSApplication.shared.terminate(nil)
    }
}
