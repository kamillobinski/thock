//
//  MenuBarController.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import SwiftUI

class MenuBarController {
    private var menu: NSMenu
    private var statusBarItem: NSStatusItem
    private weak var delegate: MenuBarControllerDelegate?
    private var hasUpdate: Bool = false
    
    private enum MenuItemTitle {
        static let app = AppInfoHelper.appName
        static let volume = "Volume"
        static let pitch = "Pitch Variation"
        static let pitchTooltip = "Each keystroke detunes itself a little - ± your chosen value. Keeps things human. Or haunted."
        static let quit = "Quit"
        static let version = "Version"
        static let settings = "Settings..."
        static let globalShortcuts = "Global Shortcuts..."
        static let openAtLogin = "Launch Thock at login"
        static let disableModifierKeys = "Disable sound for modifier keys"
        static let ignoreRapidKeyEvents = "Ignore rapid key events"
        static let autoMuteOnMusicPlayback = "Auto-mute with Music and Spotify"
        static let releaseNotes = "About this version"
        static let updateAvailable = "New Version Is Available!"
        static let updateNow = "↺ Update Now"
        static let checkForUpdates = "Check for updates..."
    }
    
    // MARK: - Init
    
    init(statusBarItem: NSStatusItem, delegate: MenuBarControllerDelegate) {
        self.menu = NSMenu()
        self.statusBarItem = statusBarItem
        self.delegate = delegate
        DispatchQueue.main.async {
            self.setupMenu()
        }
        
        // StatusBarItem left/right click event
        if let button = statusBarItem.button {
            button.target = self
            button.action = #selector(onStatusBarIconClick(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsUpdate),
            name: .settingsDidChange,
            object: nil
        )
    }
    
    // MARK: - Public API
    
    public func getMenu() -> NSMenu {
        return menu
    }
    
    public func setUpdateAvailable(_ isAvailable: Bool) {
        self.hasUpdate = isAvailable
        DispatchQueue.main.async {
            self.setupMenu()
        }
    }

    /// Updates the menu bar icon based on app state.
    func updateMenuBarIcon(for state: Bool) {
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")
        statusBarItem.button?.image?.isTemplate = true
        statusBarItem.button?.alphaValue = state ? 1.0 : 0.3
    }
    
    /// Toggles sound on/off.
    func toggleSound() {
        updateMenuBarIcon(for: AppEngine.shared.toggleIsEnabled())
    }
    
    // MARK: - Menu Setup
    
    func setupMenu() {
        menu.removeAllItems()
        updateMenuBarIcon(for: AppEngine.shared.isEnabled())
        
        addToggleMenuItem()
        addVolumeSliderItem()
        addPitchButtonRowItem()
        addSoundModesMenu()
        addGlobalShortcutsMenuItem()
        addQuickSettingsMenu()
        if hasUpdate {
            addUpdateMenuItem()
        }
        addQuitMenuItem()
    }
    
    private func addPitchButtonRowItem() {
        menu.addItem(createMenuLabel(MenuItemTitle.pitch, tooltip: MenuItemTitle.pitchTooltip))
        menu.addItem(createPitchButtonRowItem())
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Adds an enabled/disabled toggle item for the app.
    private func addToggleMenuItem() {
        let toggleItem = NSMenuItem()
        toggleItem.view = EnableAppMenuItem(title: MenuItemTitle.app, isOn: AppEngine.shared.isEnabled()) { [weak self] _ in
            self?.toggleSound()
        }
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Adds a volume slider to the menu.
    private func addVolumeSliderItem() {
        menu.addItem(createMenuLabel(MenuItemTitle.volume))
        
        let volumeItem = NSMenuItem()
        volumeItem.view = createVolumeSlider()
        menu.addItem(volumeItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    private func addQuickSettingsMenu() {
        let settingsItem = NSMenuItem(title: MenuItemTitle.settings, action: nil, keyEquivalent: "")
        let subMenu = createQuickSettingsSubmenu()
        menu.addItem(settingsItem)
        menu.setSubmenu(subMenu, for: settingsItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    private func addGlobalShortcutsMenuItem() {
        let shortcutsItem = NSMenuItem(
            title: MenuItemTitle.globalShortcuts,
            action: #selector(openGlobalShortcutsSettings),
            keyEquivalent: ","
        )
        shortcutsItem.keyEquivalentModifierMask = [.command]
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    private func addUpdateMenuItem() {
        let updateMenuItem = NSMenuItem(
            title: MenuItemTitle.updateNow,
            action: #selector(copyUpgradeCommand),
            keyEquivalent: ""
        )
        updateMenuItem.target = self
        
        menu.addItem(createMenuLabel(MenuItemTitle.updateAvailable))
        menu.addItem(updateMenuItem)
        menu.addItem(NSMenuItem.separator())
    }

    @objc private func copyUpgradeCommand() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString("brew update && brew upgrade thock", forType: .string)
            
            // Simulate Command+V to paste the command
            let source = CGEventSource(stateID: .combinedSessionState)
            let cmdd = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // CMD down
            let cmdV = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V down (correct code)
            let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) // V up
            let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) // CMD up
            
            // Add Command modifier flag to the V key events
            cmdV?.flags = .maskCommand
            cmdVUp?.flags = .maskCommand
            
            cmdd?.post(tap: .cgAnnotatedSessionEventTap)
            cmdV?.post(tap: .cgAnnotatedSessionEventTap)
            cmdVUp?.post(tap: .cgAnnotatedSessionEventTap)
            cmdUp?.post(tap: .cgAnnotatedSessionEventTap)

            // Simulate Return key to execute the command
            let returnDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true)
            let returnUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
            returnDown?.post(tap: .cgAnnotatedSessionEventTap)
            returnUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
    
    @objc private func checkForUpdates() {
        AppUpdater.shared.checkForUpdates { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let isUpdateAvailable):
                    self?.setUpdateAvailable(isUpdateAvailable)
                    
                    let alert = NSAlert()
                    if isUpdateAvailable {
                        alert.messageText = "Update Available!"
                        alert.informativeText = "A new version of Thock is available. Check the menu bar for the update option."
                        alert.alertStyle = .informational
                    } else {
                        alert.messageText = "No Updates Available"
                        alert.informativeText = "You're already running the latest version of Thock."
                        alert.alertStyle = .informational
                    }
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    
                case .failure(let error):
                    let alert = NSAlert()
                    alert.messageText = "Update Check Failed"
                    alert.informativeText = "Unable to check for updates: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Adds a quit application menu item.
    private func addQuitMenuItem() {
        let quitItem = NSMenuItem(title: MenuItemTitle.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    /// Adds a submenu for selecting sound modes.
    private func addSoundModesMenu() {
        let modeDatabase = ModeDatabase()
        let currentMode = ModeEngine.shared.getModeCurrentMode()
        
        for brand in modeDatabase.getAllBrands() {
            let brandSubMenu = createBrandSubMenu(for: brand, currentMode: currentMode, modeDatabase: modeDatabase)
            let brandMenuItem = createBrandMenuItem(brand: brand, isActive: brandSubMenu.items.contains { $0.state == .on })
            
            menu.addItem(brandMenuItem)
            menu.setSubmenu(brandSubMenu, for: brandMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
    }
    
    // MARK: - Menu Creation Helpers
    
    private func createMenuLabel(_ text: String, tooltip: String? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 20))
        
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.disabledControlTextColor
        label.frame = NSRect(x: 12, y: 2, width: 140, height: 16)
        if let tooltip = tooltip {
            label.stringValue += " 􀁜"
            label.toolTip = tooltip
        }
        
        container.addSubview(label)
        menuItem.view = container
        return menuItem
    }
    
    /// Creates a volume slider using SwiftUI inside an NSHostingView.
    private func createVolumeSlider() -> NSView {
        let hostingView = NSHostingView(rootView: VolumeSliderMenuItem(
            volume: Binding(
                get: { Double(SoundEngine.shared.getVolume()) },
                set: { _ in }
            ),
            onVolumeChange: { newValue in SoundEngine.shared.setVolume(Float(newValue)) },
            step: 0.01
        ))
        
        hostingView.frame = NSRect(x: 15, y: 0, width: 150, height: 20)
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        containerView.addSubview(hostingView)
        
        return containerView
    }
    
    /// Creates a pitch variation button row
    private func createPitchButtonRowItem() -> NSMenuItem {
        let pitchBinding = Binding<Float>(
            get: { SoundEngine.shared.getPitchVariation() },
            set: { newVal in SoundEngine.shared.setPitchVariation(newVal) }
        )
        
        let view = PitchVariationButtonRow(
            values: [0, 2.5, 5, 7.5, 10],
            selected: pitchBinding,
            onSelect: { _ in
                DispatchQueue.main.async {
                    self.setupMenu()
                }
            }
        )
        
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 180, height: 26)
        
        let item = NSMenuItem()
        item.view = hosting
        return item
    }
    
    /// Creates a submenu for a given brand, including its authors and modes.
    private func createBrandSubMenu(for brand: Brand, currentMode: Mode, modeDatabase: ModeDatabase) -> NSMenu {
        let brandSubMenu = NSMenu()
        
        for author in modeDatabase.getAuthors(for: brand) {
            guard let modes = modeDatabase.getModes(for: brand, author: author), !modes.isEmpty else { continue }
            
            if author.rawValue != Author.custom.rawValue {
                brandSubMenu.addItem(createMenuLabel("by \(author.rawValue)"))
            }
            
            for mode in modes {
                let modeItem = NSMenuItem(title: mode.name, action: #selector(changeMode(_:)), keyEquivalent: "")
                modeItem.state = (mode == currentMode) ? .on : .off
                modeItem.representedObject = mode
                modeItem.target = self
                if #available(macOS 14, *), mode.isNew {
                    modeItem.badge = NSMenuItemBadge(string: "NEW")
                }
                brandSubMenu.addItem(modeItem)
            }
            
            brandSubMenu.addItem(NSMenuItem.separator())
        }
        
        return brandSubMenu
    }
    
    /// Creates a brand menu item with optional styling if it's active.
    private func createBrandMenuItem(brand: Brand, isActive: Bool) -> NSMenuItem {
        let brandMenuItem = NSMenuItem(title: brand.rawValue, action: nil, keyEquivalent: "")
        
        if isActive {
            brandMenuItem.attributedTitle = NSAttributedString(
                string: brand.rawValue,
                attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold)]
            )
        }
        
        return brandMenuItem
    }
    
    private func createQuickSettingsSubmenu() -> NSMenu {
        let subMenu = NSMenu()
        
        // Open at login toggle
        let openAtLoginItem = NSMenuItem(
            title: MenuItemTitle.openAtLogin,
            action: #selector(toggleOpenAtLogin(_:)),
            keyEquivalent: ""
        )
        openAtLoginItem.state = SettingsEngine.shared.isOpenAtLoginEnabled() ? .on : .off
        openAtLoginItem.target = self
        subMenu.addItem(openAtLoginItem)
        
        // Disable modifier keys toggle
        let disableModKeysItem = NSMenuItem(
            title: MenuItemTitle.disableModifierKeys,
            action: #selector(toggleModifierKeysSetting(_:)),
            keyEquivalent: ""
        )
        disableModKeysItem.state = SettingsEngine.shared.isModifierKeySoundDisabled() ? .on : .off
        disableModKeysItem.target = self
        subMenu.addItem(disableModKeysItem)
        
        // Ignore rapid key events
        let ignoreRapidKeyEventsItem = NSMenuItem(
            title: MenuItemTitle.ignoreRapidKeyEvents,
            action: #selector(toggleIgnoreRapidKeyEventsSetting(_:)),
            keyEquivalent: ""
        )
        ignoreRapidKeyEventsItem.state = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled() ? .on : .off
        ignoreRapidKeyEventsItem.target = self
        subMenu.addItem(ignoreRapidKeyEventsItem)
        
        // Mute when Music app is playing
        let autoMuteOnMusicPlaybackItem = NSMenuItem(
            title: MenuItemTitle.autoMuteOnMusicPlayback,
            action: #selector(toggleAutoMuteOnMusicPlayback(_:)),
            keyEquivalent: ""
        )
        autoMuteOnMusicPlaybackItem.state = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() ? .on : .off
        autoMuteOnMusicPlaybackItem.target = self
        subMenu.addItem(autoMuteOnMusicPlaybackItem)
        
        subMenu.addItem(NSMenuItem.separator())
        
        // App version
        let versionItem = NSMenuItem(
            title: "\(MenuItemTitle.version) \(AppInfoHelper.appVersion)",
            action: nil,
            keyEquivalent: ""
        ).disabled()
        subMenu.addItem(versionItem)
        
        // What's new link
        let releaseNotesItem = NSMenuItem(
            title: MenuItemTitle.releaseNotes,
            action: #selector(openChangelog),
            keyEquivalent: ""
        )
        releaseNotesItem.target = self
        subMenu.addItem(releaseNotesItem)
        
        subMenu.addItem(NSMenuItem.separator())
        
        // Check for updates
        let checkUpdatesItem = NSMenuItem(
            title: MenuItemTitle.checkForUpdates,
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = self
        subMenu.addItem(checkUpdatesItem)
        
        return subMenu
    }
    
    // MARK: - StatusBarItem Click Handlers
    
    private func handleLeftClick(sender: NSStatusBarButton) {
        statusBarItem.menu = self.menu
        sender.performClick(nil)
        statusBarItem.menu = nil
    }
    
    private func handleRightClick(sender: NSStatusBarButton) {
        toggleSound()
        DispatchQueue.main.async {
            self.setupMenu()
        }
    }
    
    // MARK: - Actions
    
    @objc private func onStatusBarIconClick(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .rightMouseUp:
            handleRightClick(sender: sender)
        case .leftMouseUp:
            handleLeftClick(sender: sender)
        default:
            break
        }
    }
    
    @objc private func handleSettingsUpdate() {
        DispatchQueue.main.async {
            self.setupMenu()
        }
    }
    
    @objc private func toggleOpenAtLogin(_ sender: NSMenuItem) {
        sender.state = SettingsEngine.shared.toggleOpenAtLogin() ? .on : .off
    }
    
    @objc private func toggleModifierKeysSetting(_ sender: NSMenuItem) {
        sender.state = SettingsEngine.shared.toggleModifierKeySound() ? .on : .off
    }
    
    @objc private func toggleIgnoreRapidKeyEventsSetting(_ sender: NSMenuItem) {
        sender.state = SettingsEngine.shared.toggleIgnoreRapidKeyEvents() ? .on : .off
    }
    
    @objc private func toggleAutoMuteOnMusicPlayback(_ sender: NSMenuItem) {
        sender.state = SettingsEngine.shared.toggleAutoMuteOnMusicPlayback() ? .on : .off
    }
    
    @objc private func openChangelog() {
        if let url = URL(string: "https://github.com/kamillobinski/thock/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? Mode {
            SettingsEngine.shared.selectMode(mode: mode)
        }
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
    
    @objc private func openGlobalShortcutsSettings() {
        openSettingsWindow()
    }
    
    private func openSettingsWindow() {
        let settingsView = SettingsWindow()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Thock Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// A helper extension to disable menu items.
private extension NSMenuItem {
    func disabled() -> NSMenuItem {
        self.isEnabled = false
        return self
    }
}

protocol MenuBarControllerDelegate: AnyObject {
    func quitApp()
}
