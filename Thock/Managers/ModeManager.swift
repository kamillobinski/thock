//
//  ModeManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 11/03/2025.
//

import Foundation

final class ModeManager {
    static let shared = ModeManager()
    private static let defaultId: UUID = UUID(uuidString: "8f6a8074-e5a5-49f3-b3e9-f9f735b98476")!
    private var currentMode: Mode = ModeDatabase().getMode(by: (UserDefaults.standard.currentMode ?? ModeManager.defaultId))!

    func setCurrentMode(_ newMode: Mode) {
        currentMode = newMode
        UserDefaults.standard.currentMode = newMode.id
    }
    
    func getCurrentMode() -> Mode {
        return currentMode
    }
}

private extension UserDefaults {
    var currentMode: UUID? {
        get {
            if let string = string(forKey: "currentMode") {
                UUID(uuidString: string)
            } else {
                nil
            }
        }
        set { set(newValue?.uuidString, forKey: "currentMode") }
    }
}
