import Foundation
import KeyboardShortcuts
import Cocoa

class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()
    
    private init() {}
    
    func setupGlobalShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleThock) { [weak self] in
            self?.handleToggleShortcut()
        }
    }
    
    private func handleToggleShortcut() {
        DispatchQueue.main.async {
            let newState = AppEngine.shared.toggleIsEnabled()
            
            // Update the menu bar icon
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.menuBarController?.updateMenuBarIcon(for: newState)
            }
            
            // Show a subtle notification
            self.showToggleNotification(enabled: newState)
        }
    }
    
    private func showToggleNotification(enabled: Bool) {
        let notification = NSUserNotification()
        notification.title = "Thock"
        notification.informativeText = enabled ? "Enabled" : "Disabled"
        notification.soundName = nil
        notification.deliveryDate = Date()
        
        NSUserNotificationCenter.default.deliver(notification)
        
        // Remove notification after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSUserNotificationCenter.default.removeDeliveredNotification(notification)
        }
    }
}
