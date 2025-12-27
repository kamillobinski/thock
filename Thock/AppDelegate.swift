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
            if isLikelyUpdate() {
                showUpdatePermissionDialog()
            } else {
                showPermissionRequiredDialog()
            }
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
    
    /// Detects if this is likely an app update by checking for existing user data.
    private func isLikelyUpdate() -> Bool {
        let defaults = UserDefaults.standard
        
        // Check for any existing settings
        return defaults.object(forKey: "perDeviceVolume") != nil ||
        defaults.object(forKey: "currentMode") != nil ||
        defaults.object(forKey: "openAtLogin") != nil ||
        defaults.object(forKey: "disableModifierKeys") != nil ||
        defaults.object(forKey: "ignoreRapidKeyEvents") != nil ||
        defaults.object(forKey: "autoMuteOnMusicPlayback") != nil ||
        defaults.object(forKey: "idleTimeoutSeconds") != nil ||
        defaults.object(forKey: "audioBufferSize") != nil
    }
    
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
    
    /// Shows a dialog explaining why accessibility permissions are required (first-time setup).
    private func showPermissionRequiredDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Thock needs accessibility permissions to detect keyboard input and play sounds.\n\nClick 'Open System Settings' below, then enable Thock in the Accessibility list."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilitySettings()
            showWaitingAlert()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Shows a dialog for users who need to refresh permissions after an update.
    private func showUpdatePermissionDialog() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Refresh"
        alert.informativeText = "Annoying update step ahead!\nWe'd automate this if we could, but it requires the $100 Apple Developer Program.\n\n1. Remove the old Thock entry from Accessibility and quit the app.\n2. Reopen Thock and enable the new entry that appears."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit Thock")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            showWaitingAlert()
        } else if response == .alertSecondButtonReturn {
            openAccessibilitySettings()
            showWaitingAlert()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Opens System Settings to the Accessibility privacy section.
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
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

