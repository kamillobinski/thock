//
//  SoundModeManager.swift
//  Tapp
//
//  Created by Kamil Łobiński on 10/03/2025.
//

class SoundModeManager {
    static let shared = SoundModeManager()
    
    private var mode: Modes = Modes.Default
    
    func setMode(_ newMode: Modes) {
        mode = newMode
    }
    
    func getMode() -> Modes {
        return mode
    }
}
