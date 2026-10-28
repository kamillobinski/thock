import Testing
import Foundation
@testable import Thock

struct SpatialRendererTests {
    private let frames = 512

    private func energy(_ renderer: SpatialRenderer, bus: Int) -> (left: Float, right: Float) {
        var left: Float = 0, right: Float = 0
        var out = [Float](repeating: 0, count: frames * 2)
        for _ in 0..<8 {
            renderer.beginBlock(frames: frames)
            let input = renderer.busInput(bus)
            for i in 0..<frames { input[i] = Float.random(in: -0.5...0.5) }
            for i in out.indices { out[i] = 0 }
            out.withUnsafeMutableBufferPointer { renderer.render(frames: frames, into: $0.baseAddress!, gain: 1) }
            for i in 0..<frames { left += out[i * 2] * out[i * 2]; right += out[i * 2 + 1] * out[i * 2 + 1] }
        }
        return (left, right)
    }

    @Test func leftRightAndCenter() throws {
        let renderer = try #require(SpatialRenderer.make(sampleRate: 48_000, maxFrames: 1024))
        let leftBus = try #require(renderer.acquireBus(position: SoundPosition(azimuth: -60, elevation: -15)))
        let l = energy(renderer, bus: leftBus)
        renderer.releaseBus(leftBus)
        #expect(l.left > l.right * 2)

        let rightBus = try #require(renderer.acquireBus(position: SoundPosition(azimuth: 60, elevation: -15)))
        let r = energy(renderer, bus: rightBus)
        renderer.releaseBus(rightBus)
        #expect(r.right > r.left * 2)

        let centerBus = try #require(renderer.acquireBus(position: SoundPosition(azimuth: 0, elevation: -15)))
        let c = energy(renderer, bus: centerBus)
        #expect(abs(10 * log10(c.left / c.right)) < 1.5)
    }

    @Test func exhaustedPoolReusesDrainedBusWithoutStaleAudio() throws {
        let blockFrames = 32
        let renderer = try #require(SpatialRenderer.make(sampleRate: 48_000, maxFrames: blockFrames))
        var buses: [Int] = []
        for _ in 0..<SpatialRenderer.busCount {
            buses.append(try #require(renderer.acquireBus(position: .center)))
        }
        #expect(Set(buses).count == SpatialRenderer.busCount)
        #expect(renderer.acquireBus(position: .center) == nil)

        let releasedBus = try #require(buses.first)
        var out = [Float](repeating: 0, count: blockFrames * 2)
        renderer.beginBlock(frames: blockFrames)
        renderer.busInput(releasedBus)[blockFrames - 1] = 1
        renderer.releaseBus(releasedBus)
        out.withUnsafeMutableBufferPointer { renderer.render(frames: blockFrames, into: $0.baseAddress!, gain: 1) }
        #expect(renderer.acquireBus(position: .center) == nil, "A bus with a pending tail is still reserved")

        var tailEnergy: Float = 0
        for _ in 0..<((renderer.tailFrames + blockFrames - 1) / blockFrames) {
            renderer.beginBlock(frames: blockFrames)
            for i in out.indices { out[i] = 0 }
            out.withUnsafeMutableBufferPointer { renderer.render(frames: blockFrames, into: $0.baseAddress!, gain: 1) }
            for sample in out { tailEnergy += sample * sample }
        }
        #expect(tailEnergy > 0.000001, "The released voice must finish rendering its tail")

        let reusedBus = try #require(renderer.acquireBus(position: SoundPosition(azimuth: 60, elevation: -15)))
        #expect(reusedBus == releasedBus)
        renderer.beginBlock(frames: blockFrames)
        for i in out.indices { out[i] = 0 }
        out.withUnsafeMutableBufferPointer { renderer.render(frames: blockFrames, into: $0.baseAddress!, gain: 1) }
        #expect(out.allSatisfy { abs($0) < 0.000001 }, "Reusing a drained bus must not replay its previous input")
        #expect(renderer.acquireBus(position: .center) == nil)
    }

    @Test func calibrationMatchesDryLevel() throws {
        let renderer = try #require(SpatialRenderer.make(sampleRate: 48_000, maxFrames: 1024))
        let bus = try #require(renderer.acquireBus(position: SoundPosition(azimuth: 0, elevation: -15)))
        var dry: Float = 0, wetLeft: Float = 0
        var out = [Float](repeating: 0, count: frames * 2)
        for block in 0..<40 {
            renderer.beginBlock(frames: frames)
            let input = renderer.busInput(bus)
            for i in 0..<frames { input[i] = Float.random(in: -0.5...0.5) }
            for i in out.indices { out[i] = 0 }
            out.withUnsafeMutableBufferPointer { renderer.render(frames: frames, into: $0.baseAddress!, gain: SpatialRenderer.calibrationGain) }
            if block >= 4 {
                for i in 0..<frames { dry += input[i] * input[i]; wetLeft += out[i * 2] * out[i * 2] }
            }
        }
        let db = 10 * log10(wetLeft / dry)
        print("SpatialRenderer calibration: center/dry = \(db) dB")
        #expect(abs(db) < 1, "center/dry = \(db) dB")
    }
}
