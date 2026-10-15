import Testing
import Foundation
import CoreAudio
@testable import Thock

struct SpatialMathTests {
    @Test func classifyOutputKinds() {
        let cases: [(UInt32, UInt32, Bool, OutputKind)] = [
            (kAudioDeviceTransportTypeBuiltIn, 0, true, .headphones),
            (kAudioDeviceTransportTypeBuiltIn, 0, false, .speakers),
            (kAudioDeviceTransportTypeBluetooth, 0, false, .speakers),
            (kAudioDeviceTransportTypeBluetoothLE, 0, false, .speakers),
            (kAudioDeviceTransportTypeBluetooth, kAudioStreamTerminalTypeHeadphones, false, .headphones),
            (kAudioDeviceTransportTypeUSB, 0x0302, false, .headphones),
            (kAudioDeviceTransportTypeUSB, 0x0402, false, .headphones),
            (kAudioDeviceTransportTypeUSB, 0x0301, false, .speakers),
            (kAudioDeviceTransportTypeUSB, kAudioStreamTerminalTypeLine, false, .speakers),
            (kAudioDeviceTransportTypeUSB, 0, false, .speakers),
        ]
        for (transport, terminal, jackConnected, expected) in cases {
            #expect(OutputKind.classify(transportType: transport, terminalType: terminal,
                                        builtInHeadphones: jackConnected) == expected)
        }
    }

    @Test func desktopSpansAllDisplays() {
        // Main 1000×500 at the origin, a second display arranged to its left and a bit higher
        let main = CGRect(x: 0, y: 0, width: 1000, height: 500)
        let left = CGRect(x: -800, y: -100, width: 800, height: 450)
        let desktop = SpatialMath.desktopBounds([main, left])
        #expect(desktop == CGRect(x: -800, y: -100, width: 1800, height: 600))

        let onLeft = SpatialMath.mousePosition(location: CGPoint(x: -400, y: 100), displayBounds: desktop)
        let onMain = SpatialMath.mousePosition(location: CGPoint(x: 500, y: 100), displayBounds: desktop)
        #expect(onLeft.azimuth < 0 && onLeft.azimuth < onMain.azimuth)
        #expect(SpatialMath.desktopBounds([]) == .zero)
    }

    @Test func disabledIsDry() {
        let left = SoundPosition(azimuth: -60, elevation: -15)
        let route = SpatialMath.route(position: left, spatialEnabled: false, outputKind: .headphones) { _ in 3 }
        #expect(route.bus == nil && route.gains == (1, 1))
    }
}
