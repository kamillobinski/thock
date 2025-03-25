//
//  MenuBarView.swift
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
        static let quit = "Quit"
        static let version = "Version"
    }
    
    init(statusBarItem: NSStatusItem, delegate: MenuBarControllerDelegate) {
        self.menu = NSMenu()
        self.statusBarItem = statusBarItem
        self.delegate = delegate
        statusBarItem.menu = menu
        setupMenu()
    }
    
    func setupMenu() {
        menu.removeAllItems()
        
        addToggleMenuItem()
        addVolumeSliderItem()
        addSoundModesMenu()
        addVersionMenuItem()
        addQuitMenuItem()
    }
    
    /// Adds an enabled/disabled toggle item for the app.
    private func addToggleMenuItem() {
        let toggleItem = NSMenuItem()
        toggleItem.view = EnableAppMenuItem(title: MenuItemTitle.app, isOn: AppStateManager.shared.isEnabled) { [weak self] _ in
            self?.toggleSound()
        }
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Adds a volume slider to the menu.
    private func addVolumeSliderItem() {
        menu.addItem(NSMenuItem(title: MenuItemTitle.volume, action: nil, keyEquivalent: "").disabled())
        
        let volumeItem = NSMenuItem()
        volumeItem.view = createVolumeSlider()
        menu.addItem(volumeItem)
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Creates a volume slider using SwiftUI inside an NSHostingView.
    private func createVolumeSlider() -> NSView {
        let hostingView = NSHostingView(rootView: VolumeSliderMenuItem(
            volume: Binding(
                get: { Double(SoundManager.shared.getVolume()) },
                set: { _ in }
            ),
            onVolumeChange: { newValue in SoundManager.shared.setVolume(Float(newValue)) },
            step: 0.01
        ))
        
        hostingView.frame = NSRect(x: 15, y: 0, width: 150, height: 20)
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        containerView.addSubview(hostingView)
        
        return containerView
    }
    
    /// Adds a submenu for selecting sound modes.
    private func addSoundModesMenu() {
        let modeDatabase = ModeDatabase()
        let currentMode = ModeManager.shared.getCurrentMode()
        
        for brand in modeDatabase.getAllBrands() {
            let brandSubMenu = createBrandSubMenu(for: brand, currentMode: currentMode, modeDatabase: modeDatabase)
            let brandMenuItem = createBrandMenuItem(brand: brand, isActive: brandSubMenu.items.contains { $0.state == .on })
            
            menu.addItem(brandMenuItem)
            menu.setSubmenu(brandSubMenu, for: brandMenuItem)
        }
        
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Creates a submenu for a given brand, including its authors and modes.
    private func createBrandSubMenu(for brand: Brand, currentMode: Mode, modeDatabase: ModeDatabase) -> NSMenu {
        let brandSubMenu = NSMenu()
        
        for author in modeDatabase.getAuthors(for: brand) {
            guard let modes = modeDatabase.getModes(for: brand, author: author), !modes.isEmpty else { continue }
            
            brandSubMenu.addItem(NSMenuItem(title: "by \(author.rawValue)", action: nil, keyEquivalent: "").disabled())
            
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
    
    /// Adds the app version menu item.
    private func addVersionMenuItem() {
        menu.addItem(NSMenuItem(title: "\(MenuItemTitle.version) \(AppInfoHelper.appVersion)", action: nil, keyEquivalent: "").disabled())
        menu.addItem(NSMenuItem.separator())
    }
    
    /// Adds a quit application menu item.
    private func addQuitMenuItem() {
        let quitItem = NSMenuItem(title: MenuItemTitle.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    /// Updates the menu bar icon based on app state.
    func updateMenuBarIcon() {
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")
        statusBarItem.button?.alphaValue = AppStateManager.shared.isEnabled ? 1.0 : 0.5
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? Mode {
            delegate?.changeMode(to: mode)
            setupMenu()
        }
    }
    
    /// Toggles sound on/off.
    func toggleSound() {
        AppStateManager.shared.isEnabled.toggle()
        updateMenuBarIcon()
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
    func changeMode(to mode: Mode)
    func quitApp()
}
