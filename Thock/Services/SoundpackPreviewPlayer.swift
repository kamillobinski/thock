import AVFoundation
import Foundation
import OSLog

/// Plays a short burst of keystrokes from a soundpack folder, so a soundpack can be
/// heard before it is installed.
///
/// Deliberately independent of `SoundManager`: a preview must not touch the audio queue
/// or the preloaded sounds of the soundpack the user is actually typing with.
@MainActor
final class SoundpackPreviewPlayer {
    static let shared = SoundpackPreviewPlayer()

    enum PreviewError: Error {
        case noSounds
    }

    private static let keystrokeCount = 6
    private static let keystrokeInterval: TimeInterval = 0.18
    private static let keyUpDelay: TimeInterval = 0.09
    private static let leadTime: TimeInterval = 0.1

    private var players: [AVAudioPlayer] = []

    private init() {}

    /// Schedules a preview of the soundpack in `packDirectory`.
    ///
    /// The audio is held in memory, so the caller may delete a temporary soundpack
    /// directory as soon as this returns.
    ///
    /// - Returns: how long the scheduled preview will take to finish playing.
    @discardableResult
    func play(packDirectory: URL) throws -> TimeInterval {
        stop()

        let configURL = packDirectory.appendingPathComponent("config.json")
        let config = try JSONDecoder().decode(SoundpackConfig.self, from: Data(contentsOf: configURL))

        // "default" is the fallback group for keyboard packs; mouse packs only have named ones.
        guard let group = config.sounds["default"] ?? config.sounds.values.first, !group.down.isEmpty else {
            throw PreviewError.noSounds
        }

        let volume = SettingsEngine.shared.getVolume()
        var scheduled: [(offset: TimeInterval, player: AVAudioPlayer)] = []

        for index in 0..<Self.keystrokeCount {
            let offset = Double(index) * Self.keystrokeInterval
            if let file = group.down.randomElement(),
               let player = makePlayer(directory: packDirectory, file: file, volume: volume) {
                scheduled.append((offset, player))
            }
            if let file = group.up.randomElement(),
               let player = makePlayer(directory: packDirectory, file: file, volume: volume) {
                scheduled.append((offset + Self.keyUpDelay, player))
            }
        }

        // `deviceCurrentTime` is a shared output clock, so one reading lines every sound up.
        guard let start = scheduled.first?.player.deviceCurrentTime else {
            throw PreviewError.noSounds
        }

        for (offset, player) in scheduled {
            player.play(atTime: start + Self.leadTime + offset)
        }
        players = scheduled.map(\.player)

        let lastKeystroke = Double(Self.keystrokeCount - 1) * Self.keystrokeInterval + Self.keyUpDelay
        let longestSound = players.map(\.duration).max() ?? 0
        return Self.leadTime + lastKeystroke + longestSound
    }

    func stop() {
        players.forEach { $0.stop() }
        players.removeAll()
    }

    // MARK: - Private

    private func makePlayer(directory: URL, file: String, volume: Float) -> AVAudioPlayer? {
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent(file))
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            player.prepareToPlay()
            return player
        } catch {
            Logger.engine.error("Preview could not load '\(file)': \(error.localizedDescription)")
            return nil
        }
    }
}
