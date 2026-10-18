import Foundation
import CoreAudio

/// A sound source direction in degrees. Negative azimuth is left.
struct SoundPosition: Equatable {
    let azimuth: Float
    let elevation: Float

    static let center = SoundPosition(azimuth: 0, elevation: -15)
}

/// Whether the routed output device should get HRTF (headphones) or a stereo pan (speakers).
enum OutputKind: Equatable {
    case headphones
    case speakers

    /// Built-in uses the jack. Other transports, including Bluetooth, only get headphone rendering
    /// when the routed output streams identify headphones. Unknown terminals use the speaker pan.
    static func classify(transportType: UInt32, terminalType: UInt32, builtInHeadphones: Bool) -> OutputKind {
        switch transportType {
        case kAudioDeviceTransportTypeBuiltIn:
            return builtInHeadphones ? .headphones : .speakers
        default:
            return isHeadphoneTerminal(terminalType) ? .headphones : .speakers
        }
    }

    /// Core Audio reports either its own four-char terminal codes or raw USB Audio terminal types
    static func isHeadphoneTerminal(_ terminalType: UInt32) -> Bool {
        let usbHeadphones: UInt32 = 0x0302
        let usbHeadMountedDisplay: UInt32 = 0x0303
        let usbHeadset: UInt32 = 0x0402
        return [kAudioStreamTerminalTypeHeadphones, usbHeadphones, usbHeadMountedDisplay, usbHeadset].contains(terminalType)
    }
    
    /// Wired headphones on a built-in device. Intel Macs report the jack, Apple Silicon exposes a
    /// separate "External Headphones" device without a jack property but with the 'hdpn' data source.
    static func isBuiltInHeadphones(jackConnected: Bool, dataSource: UInt32?, name: String) -> Bool {
        let headphoneDataSource: UInt32 = 0x6864_706E // 'hdpn'
        return jackConnected || dataSource == headphoneDataSource || name.lowercased().contains("headphone")
    }
}

enum SpatialMath {
    /// Fraction of the full stereo field used on speakers, keeps the pan gentle
    static let speakerWidth: Float = 0.6
    /// Spatial width: azimuth in degrees of the keyboard and screen edges
    static let defaultWidth: Float = 40
    static let widthRange: ClosedRange<Float> = 15...60

    static func clampWidth(_ width: Float) -> Float {
        guard !width.isNaN else { return defaultWidth }
        return min(max(width, widthRange.lowerBound), widthRange.upperBound)
    }

    /// Balance law, not equal-power: center is unity on both sides (same level as the dry path) and
    /// the far side is only attenuated, so off-center sources are slightly quieter but never boosted
    static func panGains(azimuth: Float) -> (left: Float, right: Float) {
        let pan = speakerWidth * min(max(azimuth / 60, -1), 1)
        guard pan != 0 else { return (1, 1) }
        let theta = (pan + 1) * .pi / 4
        let root2 = Float(2).squareRoot()
        return (min(1, root2 * cos(theta)), min(1, root2 * sin(theta)))
    }

    /// The whole desktop as arranged in Displays settings, so a monitor placed left of the main one sounds left
    static func desktopBounds(_ displays: [CGRect]) -> CGRect {
        guard let first = displays.first else { return .zero }
        return displays.dropFirst().reduce(first) { $0.union($1) }
    }

    /// Maps a CG global (top-left origin) cursor location to a position across the given display
    static func mousePosition(location: CGPoint, displayBounds: CGRect, width: Float = defaultWidth) -> SoundPosition {
        guard displayBounds.width > 0, displayBounds.height > 0 else {
            return SoundPosition(azimuth: 0, elevation: -10)
        }
        let nx = Float(min(max((location.x - displayBounds.minX) / displayBounds.width, 0), 1))
        let ny = Float(min(max((location.y - displayBounds.minY) / displayBounds.height, 0), 1))
        return SoundPosition(azimuth: (nx - 0.5) * 2 * width, elevation: -5 - ny * 10)
    }

    /// Averages the channels, which keeps the level of mono and near-mono sources (nearly all key samples)
    static func monoDownmix(interleavedStereo stereo: [Float]) -> [Float] {
        (0..<stereo.count / 2).map { (frame: Int) -> Float in
            let left: Float = stereo[frame * 2]
            let right: Float = stereo[frame * 2 + 1]
            return (left + right) * 0.5
        }
    }

    /// Decides how a voice is rendered: dry (no position), HRTF bus (headphones), or speaker pan.
    /// Headphone voices fall back to the pan when no bus is free.
    static func route(position: SoundPosition?, spatialEnabled: Bool, outputKind: OutputKind,
                      acquireBus: (SoundPosition) -> Int?) -> (gains: (left: Float, right: Float), bus: Int?) {
        guard spatialEnabled, let position else { return ((1, 1), nil) }
        if outputKind == .headphones, let bus = acquireBus(position) {
            return ((1, 1), bus)
        }
        return (panGains(azimuth: position.azimuth), nil)
    }
}
