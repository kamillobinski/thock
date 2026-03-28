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
        
        if AXIsProcessTrusted() {
            continueAppInitialization()
        } else {
            menuBarController.setNeedsAuthorization(true)
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
    }
    
    private func setupGlobalShortcuts() {
        GlobalShortcutManager.shared.setupGlobalShortcuts()
    }
    
    private func initializeKeyboardEventTracker() {
        if keyboardEventTracker == nil {
            keyboardEventTracker = KeyboardEventTracker()
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
        waitForPermissionsRestored()
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
    
    private func continueAppInitialization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
        
        _ = PipeListenerService.shared
        initializeKeyboardEventTracker()
        initializeMouseEventTracker()
        initializeAudioMonitor()
        startPermissionMonitor()
        
        migrateCustomSoundsDirectoryIfNeeded()
        SoundpackEngine.shared.loadInitialSoundpacks()
        
        AudioDeviceManager.shared.startMonitoring()
        HeadphoneDetector.shared.startMonitoring()
        
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
