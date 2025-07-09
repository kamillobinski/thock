
import Foundation
import ScriptingBridge

@objc fileprivate protocol MusicApplication {
    @objc optional var playerState: MusicPlayerState { get }
}

@objc fileprivate protocol MusicTrack {
    @objc optional var name: String { get }
    @objc optional var artist: String { get }
    @objc optional var album: String { get }
}

@objc fileprivate enum MusicPlayerState: SBLong long {
    case stopped = 1718772596
    case playing = 1869573740
    case paused = 1885433203
    case fastForwarding = 1701995892
    case rewinding = 1919246196
}

class AudioMonitor {
    static let shared = AudioMonitor()
    private let musicApp: MusicApplication?

    private init() {
        musicApp = SBApplication(bundleIdentifier: "com.apple.Music")
    }

    func isMusicPlaying() -> Bool {
        guard let app = musicApp else { return false }
        return app.playerState == .playing
    }
}
