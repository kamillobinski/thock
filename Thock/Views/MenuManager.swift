//
//  MenuManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import SwiftUI

class MenuManager {
    private var menu: NSMenu
    private var statusBarItem: NSStatusItem
    private weak var delegate: MenuManagerDelegate?
    
    private enum MenuItemTitle {
        static let volume = "Volume"
        static let quit = "Quit"
        static let version = "Version"
    }
    
    init(statusBarItem: NSStatusItem, delegate: MenuManagerDelegate) {
        self.menu = NSMenu()
        self.statusBarItem = statusBarItem
        self.delegate = delegate
        statusBarItem.menu = menu
        updateMenu()
    }
    
    func updateMenu() {
        menu.removeAllItems()
        addToggleMenuItem()
        menu.addItem(NSMenuItem.separator())
        addVolumeSliderItem()
        menu.addItem(NSMenuItem.separator())
        addSoundModesMenu()
        menu.addItem(NSMenuItem.separator())
        addVersionMenuItem()
        menu.addItem(NSMenuItem.separator())
        addQuitMenuItem()
    }
    
    private func addToggleMenuItem() {
        guard let delegate = delegate else { return }
        
        let toggleItem = NSMenuItem()
        toggleItem.view = ToggleMenuItemView(title: AppInfoHelper.appName, isOn: delegate.isSoundEnabled) { [weak self] _ in
            self?.delegate?.toggleSound()
        }
        menu.addItem(toggleItem)
    }
    
    private func addVolumeSliderItem() {
        let labelItem = NSMenuItem(title: MenuItemTitle.volume, action: nil, keyEquivalent: "")
        labelItem.isEnabled = false
        menu.addItem(labelItem)
        
        let volumeItem = NSMenuItem()
        
        let hostingView = NSHostingView(rootView: VolumeSliderItemView(
            volume: Binding(
                get: { Double(SoundManager.shared.getVolume()) },
                set: { _ in }
            ),
            onVolumeChange: { newValue in
                SoundManager.shared.setVolume(Float(newValue))
            }, step: 0.01
        ))
        
        hostingView.frame = NSRect(x: 15, y: 0, width: 150, height: 20)
        
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        containerView.addSubview(hostingView)
        
        volumeItem.view = containerView
        menu.addItem(volumeItem)
        menu.update()
    }
    
    private func addSoundModesMenu() {
        let modeDatabase = ModeDatabase()
        let currentMode = ModeManager.shared.getCurrentMode()
        
        for brand in modeDatabase.getAllBrands() {
            let brandSubMenu = NSMenu()
            var isModeActiveInBrand = false
            
            for author in modeDatabase.getAuthors(for: brand) {
                guard let modes = modeDatabase.getModes(for: brand, author: author), !modes.isEmpty else { continue }
                
                let authorItem = NSMenuItem(title: "by \(author.rawValue)", action: nil, keyEquivalent: "")
                authorItem.isEnabled = false
                brandSubMenu.addItem(authorItem)
                
                for mode in modes {
                    let item = NSMenuItem(title: mode.name, action: #selector(changeMode(_:)), keyEquivalent: "")
                    item.state = (mode == currentMode) ? .on : .off
                    item.target = self
                    item.representedObject = mode
                    brandSubMenu.addItem(item)
                    
                    if mode == currentMode {
                        isModeActiveInBrand = true
                    }
                }
                brandSubMenu.addItem(NSMenuItem.separator())
            }
            
            let brandMenuItem = NSMenuItem(title: brand.rawValue, action: nil, keyEquivalent: "")
            
            if isModeActiveInBrand {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold)
                ]
                brandMenuItem.attributedTitle = NSAttributedString(string: brand.rawValue, attributes: attributes)
            } else {
                brandMenuItem.attributedTitle = NSAttributedString(string: brand.rawValue)
            }
            
            menu.addItem(brandMenuItem)
            menu.setSubmenu(brandSubMenu, for: brandMenuItem)
        }
    }
    
    private func addVersionMenuItem() {
        let versionItem = NSMenuItem(title: "\(MenuItemTitle.version) \(AppInfoHelper.appVersion)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
    }
    
    private func addQuitMenuItem() {
        let quitItem = NSMenuItem(title: MenuItemTitle.quit, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    func updateMenuBarIcon() {
        guard let delegate = delegate else { return }
        
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")
        statusBarItem.button?.alphaValue = delegate.isSoundEnabled ? 1.0 : 0.5
    }
    
    @objc private func changeMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? Mode {
            delegate?.changeMode(to: mode)
            updateMenu()
        }
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
}

protocol MenuManagerDelegate: AnyObject {
    var isSoundEnabled: Bool { get }
    
    func toggleSound()
    func changeMode(to mode: Mode)
    func quitApp()
}
