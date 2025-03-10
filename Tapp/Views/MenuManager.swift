//
//  MenuManager.swift
//  Tapp
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
        static let modes = "Modes"
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
    
    private func addSoundModesMenu() {
        let soundMenu = NSMenu()
        for sound in Modes.allCases {
            let item = NSMenuItem(title: sound.rawValue, action: #selector(changeSoundType(_:)), keyEquivalent: "")
            item.state = (sound == SoundModeManager.shared.getMode()) ? .on : .off
            item.target = self
            soundMenu.addItem(item)
        }
        
        let soundTypeItem = NSMenuItem(title: MenuItemTitle.modes, action: nil, keyEquivalent: "")
        menu.addItem(soundTypeItem)
        menu.setSubmenu(soundMenu, for: soundTypeItem)
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
    
    @objc private func changeSoundType(_ sender: NSMenuItem) {
        delegate?.changeMode(to: sender.title)
        updateMenu()
    }
    
    @objc private func quitApp() {
        delegate?.quitApp()
    }
}

protocol MenuManagerDelegate: AnyObject {
    var isSoundEnabled: Bool { get }
    //    var currentSoundMode: Modes { get }
    
    func toggleSound()
    func changeMode(to mode: String)
    func quitApp()
}
