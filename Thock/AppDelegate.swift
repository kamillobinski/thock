//
//  AppDelegate.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, MenuBarControllerDelegate {
    private var statusBarItem: NSStatusItem!
    private var menuManager: MenuBarController!
    private var keyTracker: KeyTracker!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard requestAccessibilityPermissions() else {
            exit(1)
        }
        
        initializeKeyTracker()
        loadInitialModeConfig()
        setupMenuBar()
    }
    
    /// Checks and requests accessibility permissions.
    private func requestAccessibilityPermissions() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Initializes and starts tracking keyboard events.
    private func initializeKeyTracker() {
        keyTracker = KeyTracker()
        keyTracker.startTrackingKeys()
    }
    
    /// Loads the current mode’s configuration.
    private func loadInitialModeConfig() {
        let currentMode = ModeManager.shared.getCurrentMode()
        ModeConfigManager.shared.loadModeConfig(for: currentMode)
        SoundManager.shared.preloadSounds(for: currentMode)
    }
    
    /// Sets up the macOS menu bar.
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuManager = MenuBarController(statusBarItem: statusBarItem, delegate: self)
        menuManager.updateMenuBarIcon()
    }
    
    /// Changes the sound mode.
    func changeMode(to mode: Mode) {
        ModeManager.shared.setCurrentMode(mode)
        ModeConfigManager.shared.loadModeConfig(for: mode)
        SoundManager.shared.preloadSounds(for: mode)
    }
    
    /// Quits the application cleanly.
    func quitApp() {
        keyTracker?.stopTrackingKeys()
        NSApplication.shared.terminate(nil)
    }
}
