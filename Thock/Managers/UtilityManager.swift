import Foundation

final class UtilityManager {
    static let shared = UtilityManager()
    
    var isCleaningMode = false
    
    private init() {}
}

