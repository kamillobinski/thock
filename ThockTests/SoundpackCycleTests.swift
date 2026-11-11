// Tests for SoundpackCycle, the ordering behind the next/previous soundpack
// shortcuts. See Thock/Helpers/SoundpackCycle.swift.

import Foundation
import Testing
@testable import Thock

struct SoundpackCycleTests {
    private func pack(_ name: String, brand: String, author: String = "") -> Soundpack {
        Soundpack(id: UUID(), name: name, brand: brand, author: author, category: "keyboard", path: "Soundpacks/\(name)/")
    }

    @Test func menuOrderSortsByBrandThenAuthorThenName() {
        let b = pack("B", brand: "Cherry", author: "x")
        let a = pack("A", brand: "Cherry", author: "y")
        let c = pack("C", brand: "Cherry", author: "x")
        let z = pack("Z", brand: "Akko")

        let ordered = SoundpackCycle.menuOrder([b, a, c, z])
        #expect(ordered.map(\.name) == ["Z", "B", "C", "A"])
    }

    @Test func nextMovesForwardAndWraps() {
        let a = pack("A", brand: "1"), b = pack("B", brand: "2"), c = pack("C", brand: "3")
        let packs = [c, a, b]
        #expect(SoundpackCycle.step(from: a, in: packs, direction: .next) == b)
        #expect(SoundpackCycle.step(from: c, in: packs, direction: .next) == a)
    }

    @Test func previousMovesBackwardAndWraps() {
        let a = pack("A", brand: "1"), b = pack("B", brand: "2"), c = pack("C", brand: "3")
        let packs = [a, b, c]
        #expect(SoundpackCycle.step(from: b, in: packs, direction: .previous) == a)
        #expect(SoundpackCycle.step(from: a, in: packs, direction: .previous) == c)
    }

    @Test func missingCurrentFallsBackToFirst() {
        let a = pack("A", brand: "1"), b = pack("B", brand: "2")
        let removed = pack("Gone", brand: "0")
        #expect(SoundpackCycle.step(from: nil, in: [b, a], direction: .next) == a)
        #expect(SoundpackCycle.step(from: removed, in: [b, a], direction: .previous) == a)
    }

    @Test func emptyAndSingleLists() {
        let a = pack("A", brand: "1")
        #expect(SoundpackCycle.step(from: nil, in: [], direction: .next) == nil)
        #expect(SoundpackCycle.step(from: a, in: [a], direction: .next) == a)
    }
}
