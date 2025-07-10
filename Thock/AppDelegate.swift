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
    private var menuBarController: MenuBarController!
    private var keyTracker: KeyTracker!
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard requestAccessibilityPermissions() else {
            exit(1)
        }
        
        _ = PipeListenerService.shared
        initializeKeyTracker()
        initializeAudioMonitor()
        
        ModeEngine.shared.loadInitialMode()
        setupMenuBar()
    }
    
    /// Quits the application cleanly.
    func applicationWillTerminate(_ notification: Notification) {
        keyTracker?.stopTrackingKeys()
        PipeListenerService.shared.cleanUp()
    }
    
    // MARK: - MenuBarControllerDelegate
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Setup Methods
    
    /// Checks and requests accessibility permissions.
    private func requestAccessibilityPermissions() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Initializes and starts tracking keyboard events.
    private func initializeKeyTracker() {
        if keyTracker == nil {
            keyTracker = KeyTracker()
            keyTracker.startTrackingKeys()
        }
    }
    
    /// Initializes the audio monitor to handle notifications asap from the settings engine.
    private func initializeAudioMonitor() {
        _ = AudioMonitor.shared
    }
    
    /// Sets up the macOS menu bar.
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBarController = MenuBarController(statusBarItem: statusBarItem, delegate: self)
        menuBarController.updateMenuBarIcon(for: AppEngine.shared.isEnabled())
    }
}

