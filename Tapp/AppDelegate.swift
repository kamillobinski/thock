//
//  AppDelegate.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Cocoa
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, KeyTrackerDelegate, MenuManagerDelegate {
    var statusBarItem: NSStatusItem!
    var menuManager: MenuManager!
    var isEnabled: Bool = true
    var soundType: Modes = .Default
    var keyTracker: KeyTracker!

    let keysDown = ["down1.mp3", "down2.mp3", "down3.mp3", "down4.mp3", "down5.mp3", "down6.mp3", "down7.mp3"]
    let keysUp = ["up1.mp3", "up2.mp3", "up3.mp3", "up4.mp3", "up5.mp3", "up6.mp3", "up7.mp3"]
    let spaceDown = "down_space.mp3"
    let spaceUp = "up_space.mp3"
    let downEnter = "down_enter.mp3"
    let upEnter = "up_enter.mp3"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isProcessTrusted() else {
            exit(1)
        }
        keyTracker = KeyTracker(delegate: self)

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarIcon()
        
        menuManager = MenuManager(statusBarItem: statusBarItem, delegate: self)

        keyTracker.startTrackingKeys()
    }

    func isProcessTrusted() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func updateMenuBarIcon() {
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")
        statusBarItem.button?.alphaValue = isEnabled ? 1.0 : 0.5
    }

    func handleKeyDown(_ keyCode: Int64) {
        guard isEnabled else { return }
        let sound = keyCode == 49 ? spaceDown : keyCode == 36 ? downEnter : keysDown.randomElement()!
        SoundManager.shared.playSound(soundFileName: sound, mode: soundType)
    }

    func handleKeyUp(_ keyCode: Int64) {
        guard isEnabled else { return }
        let sound = keyCode == 49 ? spaceUp : keyCode == 36 ? upEnter : keysUp.randomElement()!
        SoundManager.shared.playSound(soundFileName: sound, mode: soundType)
    }

    var isSoundEnabled: Bool { return isEnabled }
    var currentSoundMode: Modes { return soundType }

    func toggleSound() {
        isEnabled.toggle()
        updateMenuBarIcon()
    }

    func changeSoundMode(to mode: String) {
        if let newType = Modes(rawValue: mode) {
            soundType = newType
        }
    }

    func quitApp() {
        keyTracker.stopTrackingKeys()
        NSApplication.shared.terminate(nil)
    }
}
