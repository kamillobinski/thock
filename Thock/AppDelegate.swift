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
        setupMenuBar()
        if !requestAccessibilityPermissions() {
            showPermissionRequiredDialog()
            return
        }
        continueAppInitialization()
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
    
    /// Shows a dialog explaining why accessibility permissions are required and waits for them.
    private func showPermissionRequiredDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Thock needs accessibility permissions to detect keyboard input and play sounds. \n\nSeeing this after an update?\n - Click 'Open System Preferences'. \n - Remove the old entry.\n - Quit and relaunch the app.\n - Enable the new entry."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open System Preferences to Accessibility
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            self.showWaitingAlert()
        } else {
            // User chose Quit
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Shows a waiting alert while polling for permissions.
    private func showWaitingAlert() {
        let waitingAlert = NSAlert()
        waitingAlert.messageText = "Accessibility Permissions Required"
        waitingAlert.informativeText = "Waiting for permissions..."
        waitingAlert.alertStyle = .informational
        waitingAlert.addButton(withTitle: "Quit")
        
        // Track whether permissions were granted
        var permissionsGranted = false
        
        let pollingQueue = DispatchQueue.global(qos: .userInitiated)
        pollingQueue.async {
            while true {
                if AXIsProcessTrusted() {
                    // Permissions granted
                    permissionsGranted = true
                    DispatchQueue.main.async {
                        NSApp.abortModal()
                        self.continueAppInitialization()
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        // Show the waiting alert (blocks until quit or aborted)
        let response = waitingAlert.runModal()
        
        // Only quit if user clicked Quit (not if permissions were granted)
        if !permissionsGranted {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Continues app initialization after permissions are granted.
    private func continueAppInitialization() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        
        _ = PipeListenerService.shared
        initializeKeyTracker()
        initializeAudioMonitor()
        
        ModeEngine.shared.loadInitialMode()
        
        // Update the icon
        menuBarController.updateMenuBarIcon(for: AppEngine.shared.isEnabled())
        
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
}

