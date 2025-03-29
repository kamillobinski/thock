//
//  AppEngine.swift
//  Thock
//
//  Created by Kamil Łobiński on 29/03/2025.
//

import Foundation

final class AppEngine {
    static let shared = AppEngine()
    
    private init() {}
    
    func toggleIsEnabled() -> Bool {
        print("Toggle enabled")
        return setEnabled(!isEnabled())
    }
    
    func isEnabled() -> Bool {
        //        print("Get enabled: \(AppStateManager.shared.isEnabled)")
        return AppStateManager.shared.isEnabled
    }
    
    func setEnabled(_ enabled: Bool) -> Bool {
        print("Set enabled: \(enabled)")
        AppStateManager.shared.isEnabled = enabled
        return enabled
    }
}
