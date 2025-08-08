//
//  AppDelegate.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, MenuBarControllerDelegate {
    private var statusBarItem: NSStatusItem!
    var menuBarController: MenuBarController!
    private var keyTracker: KeyTracker!
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !requestAccessibilityPermissions() {
            showPermissionRequiredDialog()
            return
        }
        
        // Request notification permissions for UserNotifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        
        _ = PipeListenerService.shared
        initializeKeyTracker()
        initializeAudioMonitor()
        
        ModeEngine.shared.loadInitialMode()
        setupMenuBar()
        setupGlobalShortcuts()

        AppUpdater.shared.checkForUpdates { result in
            switch result {
            case .success(let isUpdateAvailable):
                self.menuBarController.setUpdateAvailable(isUpdateAvailable)
            case .failure(let error):
                print("Error checking for updates: \(error.localizedDescription)")
            }
        }
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
        // First check if permissions were given
        if AXIsProcessTrusted() {
            return true
        }
        
        // Check permissions without showing system dialog (we have our own)
        return AXIsProcessTrusted()
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
    
    /// Sets up global keyboard shortcuts.
    private func setupGlobalShortcuts() {
        GlobalShortcutManager.shared.setupGlobalShortcuts()
    }
    
    /// Shows a dialog explaining why accessibility permissions are required and exits the app.
    private func showPermissionRequiredDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Thock needs accessibility permissions to detect keyboard input and play sounds. Without these permissions, the app cannot function."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Accessibility
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
        
        NSApplication.shared.terminate(nil)
    }
}

