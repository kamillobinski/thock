import OSLog

// MARK: - Thock Logger

extension Logger {
    /// The app's bundle identifier used as the subsystem for all loggers
    private static let subsystem = Bundle.main.bundleIdentifier ?? "dev.kamillobinski.Thock"
    
    // MARK: - Categories
    
    /// Audio system logging (SoundManager, audio queue, buffers)
    static let audio = Logger(subsystem: subsystem, category: "audio")
    
    /// Latency measurement and performance tracking
    static let latency = Logger(subsystem: subsystem, category: "latency")
    
    /// Sound engine orchestration (sound selection, playback coordination)
    static let engine = Logger(subsystem: subsystem, category: "engine")
    
    /// Keyboard event handling and key mapping
    static let keyboard = Logger(subsystem: subsystem, category: "keyboard")
    
    /// Settings and preferences management
    static let settings = Logger(subsystem: subsystem, category: "settings")
    
    /// App lifecycle events (launch, terminate, state changes)
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    
    /// UI-related logging (views, user interactions)
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
