import Foundation

final class AppEngine {
    static let shared = AppEngine()
    
    private init() {}
    
    func toggleIsEnabled() -> Bool {
        return setEnabled(!isEnabled())
    }
    
    func isEnabled() -> Bool {
        return AppStateManager.shared.isEnabled
    }
    
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        AppStateManager.shared.isEnabled = enabled
        NotificationCenter.default.post(name: .appStateDidChange, object: nil)
        return enabled
    }
}
