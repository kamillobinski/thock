import Foundation

final class UtilityManager {
    static let shared = UtilityManager()
    
    private let lock = NSLock()
    private var _isCleaningMode = false
    
    var isCleaningMode: Bool {
        get { lock.withLock { _isCleaningMode } }
        set { lock.withLock { _isCleaningMode = newValue } }
    }
    
    private init() {}
}

