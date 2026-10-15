import Testing
@testable import Thock

struct VolumeLevelsTests {
    @Test func sourceLevelsPreserveExistingMasterByDefault() {
        let levels = VolumeLevels(master: 0.37)
        #expect(levels.gain(for: .keyboard) == 0.37)
        #expect(levels.gain(for: .mouse) == 0.37)
    }

    @Test func masterScalesEachSourceIndependently() {
        let levels = VolumeLevels(master: 0.5, keyboard: 0.8, mouse: 0.2)
        #expect(levels.gain(for: .keyboard) == 0.4)
        #expect(levels.gain(for: .mouse) == 0.1)
    }

    @Test func masterMuteSilencesBothSources() {
        let levels = VolumeLevels(master: 0, keyboard: 0.8, mouse: 0.2)
        #expect(levels.gain(for: .keyboard) == 0)
        #expect(levels.gain(for: .mouse) == 0)
    }

    @Test func keyboardMuteLeavesMouseAudible() {
        let levels = VolumeLevels(master: 0.5, keyboard: 0, mouse: 0.6)
        #expect(levels.gain(for: .keyboard) == 0)
        #expect(levels.gain(for: .mouse) == 0.3)
    }

    @Test func mouseMuteLeavesKeyboardAudible() {
        let levels = VolumeLevels(master: 0.5, keyboard: 0.6, mouse: 0)
        #expect(levels.gain(for: .keyboard) == 0.3)
        #expect(levels.gain(for: .mouse) == 0)
    }

    @Test(arguments: [
        (Float(-0.1), Float(0)), (0, 0), (0.42, 0.42), (1, 1), (1.1, 1),
        (.nan, 0), (.infinity, 0), (-.infinity, 0)
    ])
    func channelVolumesStayFiniteAndWithinRange(input: Float, expected: Float) {
        #expect(VolumeLevels.clamped(input) == expected)
    }
}
