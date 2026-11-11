import Foundation
import KeyboardShortcuts
import Cocoa
import UserNotifications

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private init() {}
    
    func setupGlobalShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleThock) { [weak self] in
            self?.handleToggleShortcut()
        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleCleaningMode) {
            SettingsEngine.shared.toggleCleaningMode()
        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleKeyOverlay) {
            DispatchQueue.main.async {
                _ = SettingsEngine.shared.toggleKeyOverlay()
            }
        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleKeyOverlayControls) {
            DispatchQueue.main.async {
                KeyOverlayManager.shared.toggleControlBar()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .nextKeyboardSoundpack) { [weak self] in
            self?.handleCycleKeyboardSoundpack(.next)
        }

        KeyboardShortcuts.onKeyDown(for: .previousKeyboardSoundpack) { [weak self] in
            self?.handleCycleKeyboardSoundpack(.previous)
        }
    }

    private func handleToggleShortcut() {
        DispatchQueue.main.async {
            let newState = AppEngine.shared.toggleIsEnabled()

            // Show a subtle notification
            self.showNotification(body: newState ? "Enabled" : "Disabled")
        }
    }

    private func handleCycleKeyboardSoundpack(_ direction: SoundpackCycle.Direction) {
        DispatchQueue.main.async {
            // Re-read the installed packs on each press: packs can be added or
            // removed while the app runs (registry installs, custom folder).
            let installed = SoundpackDatabase().getSoundpacks(for: "keyboard")
            let current = SoundpackEngine.shared.getCurrentKeyboardSoundpack()
            guard let target = SoundpackCycle.step(from: current, in: installed, direction: direction),
                  target != current else { return }

            SoundpackEngine.shared.applyKeyboard(soundpack: target)
            // The user can't see the menu when using the shortcut, so name the pack.
            self.showNotification(body: target.name)
        }
    }

    private func showNotification(body: String) {
        let center = UNUserNotificationCenter.current()
        
        // Request authorization if not already granted
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Thock"
            content.body = body
            content.sound = nil
            content.interruptionLevel = .passive
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "thock-toggle-\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error showing notification: \(error)")
                }
            }
            
            // Remove notification after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                center.removeAllDeliveredNotifications()
            }
        }
    }
}
