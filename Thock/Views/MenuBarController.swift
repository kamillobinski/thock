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
    
    private enum MenuItemTitle {
        static let app = AppInfoHelper.appName
        static let volume = "Volume"
        static let pitch = "Pitch Variation"
        static let pitchTooltip = "Each keystroke detunes itself a little - ± your chosen value. Keeps things human. Or haunted."
        static let quit = "Quit"
        static let version = "Version"
        static let settings = "Settings..."
        static let openAtLogin = "Launch Thock at Login"
        static let disableModifierKeys = "Disable Sound for Modifier Keys"
        static let ignoreRapidKeyEvents = "Ignore rapid key events"
        static let whatsNew = "What's new?"
    }
    
    // MARK: - Init
    
    init(statusBarItem: NSStatusItem, delegate: MenuBarControllerDelegate) {
        self.menu = NSMenu()
        self.statusBarItem = statusBarItem
        self.delegate = delegate
        setupMenu()
        
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
        addQuickSettingsMenu()
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
        
        subMenu.addItem(NSMenuItem.separator())
        
        // What's new link
        let whatsNewItem = NSMenuItem(
            title: MenuItemTitle.whatsNew,
            action: #selector(openChangelog),
            keyEquivalent: ""
        )
        whatsNewItem.target = self
        subMenu.addItem(whatsNewItem)
        
        subMenu.addItem(NSMenuItem.separator())
        
        // App version
        let versionItem = NSMenuItem(
            title: "\(MenuItemTitle.version) \(AppInfoHelper.appVersion)",
            action: nil,
            keyEquivalent: ""
        ).disabled()
        subMenu.addItem(versionItem)
        
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
        setupMenu()
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
        setupMenu()
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
