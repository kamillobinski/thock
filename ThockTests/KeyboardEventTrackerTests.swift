import Testing
@testable import Thock

struct KeyboardEventTrackerTests {
    @Test func pressRightAfterAnotherKeysReleaseStillSounds() {
        let tracker = KeyboardEventTracker()
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: true, at: 1000))
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: false, at: 1090))
        // Rolling onto the next key 5 ms after letting go of the last one
        #expect(!tracker.isRapid(keyCode: 1, isKeyDown: true, at: 1095))
        #expect(!tracker.isRapid(keyCode: 1, isKeyDown: false, at: 1180))
    }

    @Test func releaseRightAfterAnotherKeysPressStillSounds() {
        let tracker = KeyboardEventTracker()
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: true, at: 1000))
        #expect(!tracker.isRapid(keyCode: 1, isKeyDown: true, at: 1100))
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: false, at: 1105))
    }

    @Test func burstOfKeystrokesKeepsOnlyTheFirst() {
        // A tool posting three keystrokes a millisecond apart
        let tracker = KeyboardEventTracker()
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: true, at: 1000))
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: false, at: 1001))
        #expect(tracker.isRapid(keyCode: 1, isKeyDown: true, at: 1002))
        #expect(tracker.isRapid(keyCode: 1, isKeyDown: false, at: 1003))
        #expect(tracker.isRapid(keyCode: 2, isKeyDown: true, at: 1004))
        #expect(tracker.isRapid(keyCode: 2, isKeyDown: false, at: 1005))
    }

    @Test func mutedKeySoundsAgainOnItsNextPress() {
        let tracker = KeyboardEventTracker()
        #expect(!tracker.isRapid(keyCode: 0, isKeyDown: true, at: 1000))
        #expect(tracker.isRapid(keyCode: 1, isKeyDown: true, at: 1002))
        #expect(tracker.isRapid(keyCode: 1, isKeyDown: false, at: 1100))
        #expect(!tracker.isRapid(keyCode: 1, isKeyDown: true, at: 1500))
        #expect(!tracker.isRapid(keyCode: 1, isKeyDown: false, at: 1600))
    }
}
