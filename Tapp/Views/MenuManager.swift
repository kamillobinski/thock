//
//  MenuManager.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa

class MenuManager {
    private var menu: NSMenu
    private var statusBarItem: NSStatusItem
    private weak var delegate: MenuManagerDelegate?

    init(statusBarItem: NSStatusItem, delegate: MenuManagerDelegate) {
        self.menu = NSMenu()
        self.statusBarItem = statusBarItem
        self.delegate = delegate
        updateMenu()
        statusBarItem.menu = menu
    }

    func updateMenu() {
        menu.removeAllItems()

        let toggleItem = NSMenuItem(
            title: delegate?.isSoundEnabled == true ? "Disable Sound" : "Enable Sound",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        toggleItem.target = self

        let iconName = delegate?.isSoundEnabled == true ? "x.circle.fill" : "checkmark.circle.fill"
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            icon.size = NSSize(width: 16, height: 16)
            toggleItem.image = icon
        }

        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())

        let soundMenu = NSMenu()
        for sound in Modes.allCases {
            let item = NSMenuItem(title: sound.rawValue, action: #selector(changeSoundType(_:)), keyEquivalent: "")
            item.state = (sound == delegate?.currentSoundMode) ? .on : .off
            item.target = self
            soundMenu.addItem(item)
        }

        let soundTypeItem = NSMenuItem(title: "Modes", action: nil, keyEquivalent: "")
        menu.addItem(soundTypeItem)
        menu.setSubmenu(soundMenu, for: soundTypeItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func changeSoundType(_ sender: NSMenuItem) {
        delegate?.changeSoundMode(to: sender.title)
        updateMenu()
    }

    @objc private func toggleSound() {
        delegate?.toggleSound()
        updateMenu()
    }

    @objc private func quitApp() {
        delegate?.quitApp()
    }
}

protocol MenuManagerDelegate: AnyObject {
    var isSoundEnabled: Bool { get }
    var currentSoundMode: Modes { get }
    
    func toggleSound()
    func changeSoundMode(to mode: String)
    func quitApp()
}
