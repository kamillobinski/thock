//
//  OpenAtLoginManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 28/03/2025.
//

import ServiceManagement

/// Manages enabling or disabling the app's login item using `SMAppService`.
enum OpenAtLoginManager {
    
    /// Reference to the main app's login item service.
    /// Used to register or unregister the app for login at system startup.
    private static var appService: SMAppService {
        SMAppService.mainApp
    }

    /// Registers or unregisters the app as a login item based on the user's preference.
    /// - Parameter enabled: If `true`, app is added to login items. If `false`, it's removed.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try appService.register()
            } else {
                try appService.unregister()
            }
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") login item: \(error.localizedDescription)")
        }
    }

    /// Returns whether the app is currently set to launch at login.
    static func isEnabled() -> Bool {
        return appService.status == .enabled
    }
}
