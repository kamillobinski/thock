
import Foundation
import ScriptingBridge
import os.log

@objc public enum MusicPlayerState: RawRepresentable, Equatable {
    case stopped
    case playing
    case paused
    case fastForwarding
    case rewinding
    case unknown(AEKeyword)

    public typealias RawValue = AEKeyword

    public init(rawValue: AEKeyword) {
        switch rawValue {
        case 0x6b505353: self = .stopped // 'kPSS'
        case 0x6b505350: self = .playing // 'kPSP'
        case 0x6b505370: self = .paused // 'kPSp'
        case 0x6b505346: self = .fastForwarding // 'kPSF'
        case 0x6b505352: self = .rewinding // 'kPSR'
        default:
            self = .unknown(rawValue)
        }
    }

    public var rawValue: AEKeyword {
        switch self {
        case .stopped: return 0x6b505353
        case .playing: return 0x6b505350
        case .paused: return 0x6b505370
        case .fastForwarding: return 0x6b505346
        case .rewinding: return 0x6b505352
        case .unknown(let val): return val
        }
    }
}

@objc public protocol MusicApplication {
    @objc optional var playerState: MusicPlayerState { get }
    var isRunning: Bool { get }
}

extension SBApplication: MusicApplication {}

class AudioMonitor {
    static let shared = AudioMonitor()

    private let musicApp: MusicApplication?
    private let logger = OSLog(subsystem: "com.kamillobinski.thock", category: "AudioMonitor")

    private init() {
        os_log("Initializing AudioMonitor.", log: self.logger, type: .info)
        self.musicApp = SBApplication(bundleIdentifier: "com.apple.Music")
        if self.musicApp == nil {
            os_log("Failed to get SBApplication instance for com.apple.Music.", log: self.logger, type: .error)
        }
    }

    func isMusicPlaying() -> Bool {
        os_log("Checking if music is playing...", log: self.logger, type: .debug)

        guard let musicApp = self.musicApp else {
            os_log("Music application instance is nil.", log: aelf.logger, type: .error)
            return false
        }
        
        guard musicApp.isRunning else {
            os_log("Music application is not running.", log: self.logger, type: .info)
            return false
        }

        os_log("Music.app is running. Querying player state.", log: self.logger, type: .debug)
        let currentState = musicApp.playerState
        
        if let state = currentState {
            if case .unknown(let rawValue) = state {
                os_log("Received unknown player state with rawValue: %d", log: self.logger, type: .error, rawValue)
            }
            os_log("Successfully retrieved player state: %{public}@", log: self.logger, type: .info, String(describing: state))
            return state == .playing
        } else {
            os_log("Failed to retrieve player state. It returned nil. This is likely a permissions issue.", log: self.logger, type: .error)
            os_log("Please ensure Thock has Automation permissions for Music.app in System Settings > Privacy & Security > Automation.", log: self.logger, type: .error)
            return false
        }
    }
}
