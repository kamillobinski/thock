import Cocoa
import AppKit
import UserNotifications
import OSLog

class AppDelegate: NSObject, NSApplicationDelegate, MenuBarControllerDelegate {
    private var statusBarItem: NSStatusItem!
    var menuBarController: MenuBarController!
    private var keyboardEventTracker: KeyboardEventTracker!
    private var mouseEventTracker: MouseEventTracker!
    private var permissionMonitor: DispatchSourceTimer?
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        initializeAudio()

        if #available(macOS 14.0, *), OnboardingWindowController.shared.shouldShowOnLaunch {
            OnboardingWindowController.shared.statusItemButton = statusBarItem.button
            OnboardingWindowController.shared.show()
        }

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "onboardingSimulateNoAccess") || UserDefaults.standard.bool(forKey: "onboardingShowRecovery") {
            showPermissionRecovery(takeFocus: !UserDefaults.standard.bool(forKey: "onboardingSimulateRevocation"))
        }
        #endif

        if AXIsProcessTrusted() {
            continueAppInitialization()
        } else {
            menuBarController.setNeedsAuthorization(true)
            showPermissionRecovery(takeFocus: true)
            waitForPermissionsRestored()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        permissionMonitor?.cancel()
        keyboardEventTracker?.stopTracking()
        mouseEventTracker?.stopTracking()
        PipeListenerService.shared.cleanUp()
    }
    
    // MARK: - MenuBarControllerDelegate
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - Setup
    
    private func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBarController = MenuBarController(statusBarItem: statusBarItem, delegate: self)
        menuBarController.updateMenuBarIcon(for: AppEngine.shared.isEnabled())
        AppUpdater.shared.onUpdateAvailabilityChange = { [weak self] isAvailable in
            self?.menuBarController.setUpdateAvailable(isAvailable)
        }
        AppUpdater.shared.start()
    }

    private func setupGlobalShortcuts() {
        GlobalShortcutManager.shared.setupGlobalShortcuts()
    }
    
    private func initializeKeyboardEventTracker() {
        if keyboardEventTracker == nil {
            keyboardEventTracker = KeyboardEventTracker()
            keyboardEventTracker.onKeyVisualEvent = { keyCode, isKeyDown in
                KeyOverlayManager.shared.handleKeyEvent(keyCode: keyCode, isKeyDown: isKeyDown)
                KeyHudManager.shared.handleKeyEvent(keyCode: keyCode, isKeyDown: isKeyDown)
            }
            keyboardEventTracker.onKeyVisualReset = {
                KeyOverlayManager.shared.model.reset()
                KeyHudManager.shared.model.reset()
            }
            keyboardEventTracker.startTracking()
        }
    }
    
    private func initializeMouseEventTracker() {
        if mouseEventTracker == nil {
            mouseEventTracker = MouseEventTracker()
            mouseEventTracker.startTrackingIfEnabled()
        }
    }
    
    private func initializeAudioMonitor() {
        _ = AudioMonitor.shared
    }
    
    // MARK: - Permission Monitoring
    
    private func startPermissionMonitor() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 1, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self, !AXIsProcessTrusted() else { return }
            DispatchQueue.main.async { self.handlePermissionsRevoked() }
        }
        timer.resume()
        permissionMonitor = timer
    }
    
    private func handlePermissionsRevoked() {
        permissionMonitor?.cancel()
        permissionMonitor = nil
        
        keyboardEventTracker?.stopTracking()
        keyboardEventTracker = nil
        mouseEventTracker?.stopTracking()
        mouseEventTracker = nil
        
        menuBarController.setNeedsAuthorization(true)
        showPermissionRecovery(takeFocus: false)
        waitForPermissionsRestored()
    }

    private func showPermissionRecovery(takeFocus: Bool) {
        if #available(macOS 14.0, *) {
            MainActor.assumeIsolated {
                OnboardingWindowController.shared.showPermissionRecovery(takeFocus: takeFocus)
            }
        }
    }
    
    private func waitForPermissionsRestored() {
        DispatchQueue.global(qos: .utility).async {
            while !AXIsProcessTrusted() {
                Thread.sleep(forTimeInterval: 1.0)
            }
            DispatchQueue.main.async {
                self.menuBarController.setNeedsAuthorization(false)
                self.continueAppInitialization()
            }
        }
    }
    
    // MARK: - Initialization
    
    private func initializeAudio() {
        migrateCustomSoundsDirectoryIfNeeded()
        SoundpackEngine.shared.loadInitialSoundpacks()

        AudioDeviceManager.shared.startMonitoring()
        HeadphoneDetector.shared.startMonitoring()
    }

    private func continueAppInitialization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }

        _ = PipeListenerService.shared
        initializeKeyboardEventTracker()
        NotificationCenter.default.post(name: .keyboardTrackingDidStart, object: nil)
        initializeMouseEventTracker()
        initializeAudioMonitor()
        startPermissionMonitor()

        menuBarController.updateMenuBarIcon(for: AppEngine.shared.isEnabled())
        
        KeyOverlayManager.shared.applyInitialState()
        KeyHudManager.shared.applyInitialState()
        
        setupGlobalShortcuts()
        setupSleepWakeMonitoring()
        
    }
    
    // MARK: - Migration
    
    private func migrateCustomSoundsDirectoryIfNeeded() {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock")
        let old = support.appendingPathComponent("CustomSounds")
        let new = support.appendingPathComponent("Soundpacks")
        
        guard FileManager.default.fileExists(atPath: old.path),
              !FileManager.default.fileExists(atPath: new.path) else { return }
        
        try? FileManager.default.moveItem(at: old, to: new)
    }
    
    // MARK: - Sleep/Wake
    
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
    
    @objc private func handleSystemWillSleep(_ notification: Notification) {
        Logger.audio.info("System going to sleep")
    }
    
    @objc private func handleSystemDidWake(_ notification: Notification) {
        Logger.audio.info("System woke from sleep, reinitializing audio system")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            AudioDeviceManager.shared.enumerateAndCacheDevices()
            SoundManager.shared.reinitializeAfterWake()
        }
    }
}
