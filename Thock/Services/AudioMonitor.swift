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
        guard let musicApp = self.musicApp, musicApp.isRunning else { return false }
        return musicApp.playerState == .playing
    }
}
