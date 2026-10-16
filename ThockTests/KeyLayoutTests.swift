import Testing
@testable import Thock

struct KeyLayoutTests {
    @Test @MainActor func capturedLayoutKeepsItsPositionWhenAnotherKeyboardTypes() {
        let iso = KeyLayout.Physical.fromKeyboardType(41)
        let ansi = KeyLayout.Physical.fromKeyboardType(40)

        // Resolve in reverse event order, as playback on the global queue can do.
        let ansiPosition = KeyLayout.position(for: 50, layout: ansi)
        let isoPosition = KeyLayout.position(for: 50, layout: iso)
        #expect(ansiPosition.elevation == -12)
        #expect(isoPosition.elevation == -18)
        #expect(isoPosition.azimuth > ansiPosition.azimuth)
    }
}
