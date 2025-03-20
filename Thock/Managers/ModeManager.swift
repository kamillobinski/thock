//
//  ModeManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 11/03/2025.
//

import Foundation

class ModeManager {
    static let shared = ModeManager()
    
    private var currentMode: Mode = ModeDatabase().getMode(
        by: UUID(uuidString: "8f6a8074-e5a5-49f3-b3e9-f9f735b98476")!
    )!
    
    func setCurrentMode(_ newMode: Mode) {
        currentMode = newMode
    }
    
    func getCurrentMode() -> Mode {
        return currentMode
    }
}
