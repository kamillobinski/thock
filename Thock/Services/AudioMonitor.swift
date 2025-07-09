import Foundation
import ScriptingBridge

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

    private init() {
        self.musicApp = SBApplication(bundleIdentifier: "com.apple.Music")
    }

    func isMusicPlaying() -> Bool {
        guard let musicApp = self.musicApp, musicApp.isRunning else {
            return false
        }

        // Safely unwrap the optional playerState.
        // This is the critical change. If ScriptingBridge fails to get the
        // state (e.g., due to permissions), it will return nil. The previous
        // implementation would just result in `false` without making it
        // clear why. This is more robust.
        if let currentState = musicApp.playerState {
            return currentState == .playing
        }

        // If we can't get the state, assume it's not playing.
        return false
    }
}
