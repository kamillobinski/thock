import Foundation

final class SoundpackManager {
    static let shared = SoundpackManager()
    
    private var currentKeyboardSoundpack: Soundpack?
    private var currentMouseSoundpack: Soundpack?
    
    private init() {
        let db = SoundpackDatabase()
        
        if let id = UserDefaults.standard.currentKeyboardSoundpackId {
            currentKeyboardSoundpack = db.getSoundpack(by: id) ?? db.getSoundpacks(for: "keyboard").first
        } else {
            currentKeyboardSoundpack = db.getSoundpacks(for: "keyboard").first
        }
        UserDefaults.standard.currentKeyboardSoundpackId = currentKeyboardSoundpack?.id
        
        if let id = UserDefaults.standard.currentMouseSoundpackId {
            currentMouseSoundpack = db.getSoundpack(by: id) ?? db.getSoundpacks(for: "mouse").first
        } else {
            currentMouseSoundpack = db.getSoundpacks(for: "mouse").first
        }
        UserDefaults.standard.currentMouseSoundpackId = currentMouseSoundpack?.id
    }
    
    func setCurrentKeyboardSoundpack(_ soundpack: Soundpack) {
        currentKeyboardSoundpack = soundpack
        UserDefaults.standard.currentKeyboardSoundpackId = soundpack.id
    }
    
    func setCurrentMouseSoundpack(_ soundpack: Soundpack) {
        currentMouseSoundpack = soundpack
        UserDefaults.standard.currentMouseSoundpackId = soundpack.id
    }
    
    func getCurrentKeyboardSoundpack() -> Soundpack? {
        return currentKeyboardSoundpack
    }
    
    func getCurrentMouseSoundpack() -> Soundpack? {
        return currentMouseSoundpack
    }
    
    /// Re-validates both current soundpacks and falls back to first available of each category.
    func reloadCurrentSoundpacks() {
        let db = SoundpackDatabase()
        
        if let ksp = currentKeyboardSoundpack, db.getSoundpack(by: ksp.id) == nil {
            currentKeyboardSoundpack = db.getSoundpacks(for: "keyboard").first
            UserDefaults.standard.currentKeyboardSoundpackId = currentKeyboardSoundpack?.id
        }
        
        if let msp = currentMouseSoundpack, db.getSoundpack(by: msp.id) == nil {
            currentMouseSoundpack = db.getSoundpacks(for: "mouse").first
            UserDefaults.standard.currentMouseSoundpackId = currentMouseSoundpack?.id
        }
    }
}

private extension UserDefaults {
    var currentKeyboardSoundpackId: UUID? {
        get { (string(forKey: "currentKeyboardSoundpack")).flatMap { UUID(uuidString: $0) } }
        set { set(newValue?.uuidString, forKey: "currentKeyboardSoundpack") }
    }
    
    var currentMouseSoundpackId: UUID? {
        get { (string(forKey: "currentMouseSoundpack")).flatMap { UUID(uuidString: $0) } }
        set { set(newValue?.uuidString, forKey: "currentMouseSoundpack") }
    }
}
