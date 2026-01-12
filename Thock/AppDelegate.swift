import Cocoa
import AppKit
import UserNotifications
import OSLog

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
        alert.messageText = L10n.permissionRequired
        alert.informativeText = L10n.permissionMessage
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.openSystemSettings)
        alert.addButton(withTitle: L10n.quit)
        
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
        alert.messageText = L10n.permissionRefresh
        alert.informativeText = L10n.permissionRefreshMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.done)
        alert.addButton(withTitle: L10n.openSystemSettings)
        alert.addButton(withTitle: L10n.quitThock)
        
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
        waitingAlert.messageText = L10n.permissionRequired
        waitingAlert.informativeText = L10n.waitingForPermissions
        waitingAlert.alertStyle = .informational
        waitingAlert.addButton(withTitle: L10n.quit)
        
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
        _ = waitingAlert.runModal()
        
        // Only quit if user clicked Quit (not if permissions were granted)
        if !permissionsGranted {
            NSApplication.shared.terminate(nil)
        }
    }
    
    /// Sets up monitoring for system sleep/wake events.
    private func setupSleepWakeMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    /// Handles system going to sleep.
    @objc private func handleSystemWillSleep(_ notification: Notification) {
        Logger.audio.info("System going to sleep")
    }
    
    /// Handles system waking from sleep.
    @objc private func handleSystemDidWake(_ notification: Notification) {
        Logger.audio.info("System woke from sleep, reinitializing audio system")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AudioDeviceManager.shared.enumerateAndCacheDevices()
            SoundManager.shared.reinitializeAfterWake()
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
        setupSleepWakeMonitoring()
        
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

