import Foundation
import KeyboardShortcuts
import Cocoa
import UserNotifications

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private init() {}
    
    func setupGlobalShortcuts() {
        // Set default shortcut if none exists
        //        if KeyboardShortcuts.getShortcut(for: .toggleThock) == nil {
        //            KeyboardShortcuts.setShortcut(.init(.t, modifiers: [.command, .shift]), for: .toggleThock)
        //        }
        
        KeyboardShortcuts.onKeyDown(for: .toggleThock) { [weak self] in
            self?.handleToggleShortcut()
        }
    }
    
    private func handleToggleShortcut() {
        DispatchQueue.main.async {
            let newState = AppEngine.shared.toggleIsEnabled()
            
            // Show a subtle notification
            self.showToggleNotification(enabled: newState)
        }
    }
    
    private func showToggleNotification(enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        
        // Request authorization if not already granted
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Thock"
            content.body = enabled ? "Enabled" : "Disabled"
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
