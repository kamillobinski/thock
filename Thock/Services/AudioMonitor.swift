import Foundation
import ScriptingBridge
import os.log

@objc public enum MusicPlayerState: AEKeyword {
    case stopped        = 0x6b505353 // 'kPSS'
    case playing        = 0x6b505350 // 'kPSP'
    case paused         = 0x6b505370 // 'kPSp'
    case fastForwarding = 0x6b505346 // 'kPSF'
    case rewinding      = 0x6b505352 // 'kPSR'
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
            os_log("Music application instance is nil.", log: self.logger, type: .error)
            return false
        }
        
        guard musicApp.isRunning else {
            os_log("Music application is not running.", log: self.logger, type: .info)
            return false
        }

        os_log("Music.app is running. Querying player state.", log: self.logger, type: .debug)
        let currentState = musicApp.playerState
        
        if let state = currentState {
            os_log("Successfully retrieved player state: %{public}@", log: self.logger, type: .info, String(describing: state))
            return state == .playing
        } else {
            os_log("Failed to retrieve player state. It returned nil. This is likely a permissions issue.", log: self.logger, type: .error)
            os_log("Please ensure Thock has Automation permissions for Music.app in System Settings > Privacy & Security > Automation.", log: self.logger, type: .error)
            return false
        }
    }
}
