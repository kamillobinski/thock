import Testing
@testable import Thock

struct KeyMapperTests {

    @Test func mapsLetterKeys() {
        #expect(KeyMapper.fromKeyCode(0) == "a")
        #expect(KeyMapper.fromKeyCode(1) == "s")
        #expect(KeyMapper.fromKeyCode(12) == "q")
        #expect(KeyMapper.fromKeyCode(35) == "p")
        #expect(KeyMapper.fromKeyCode(46) == "m")
    }

    @Test func mapsTopRowNumberKeys() {
        #expect(KeyMapper.fromKeyCode(18) == "1")
        #expect(KeyMapper.fromKeyCode(23) == "5")
        #expect(KeyMapper.fromKeyCode(29) == "0")
    }

    @Test func mapsNumpadKeys() {
        #expect(KeyMapper.fromKeyCode(83) == "1")
        #expect(KeyMapper.fromKeyCode(67) == "*")
        #expect(KeyMapper.fromKeyCode(71) == "clear")
    }

    @Test func mapsWhitespaceAndEditingKeys() {
        #expect(KeyMapper.fromKeyCode(49) == "space")
        #expect(KeyMapper.fromKeyCode(48) == "tab")
        #expect(KeyMapper.fromKeyCode(51) == "del")
        #expect(KeyMapper.fromKeyCode(53) == "esc")
    }

    @Test func mapsNavigationKeys() {
        #expect(KeyMapper.fromKeyCode(123) == "arrLeft")
        #expect(KeyMapper.fromKeyCode(124) == "arrRight")
        #expect(KeyMapper.fromKeyCode(125) == "arrDown")
        #expect(KeyMapper.fromKeyCode(126) == "arrUp")
    }

    @Test func mapsFunctionKeys() {
        #expect(KeyMapper.fromKeyCode(122) == "f1")
        #expect(KeyMapper.fromKeyCode(111) == "f12")
    }

    @Test func mapsModifierKeysToSoundNames() {
        #expect(KeyMapper.fromKeyCode(56) == "shiftLeft")
        #expect(KeyMapper.fromKeyCode(60) == "shiftRight")
        #expect(KeyMapper.fromKeyCode(58) == "optionLeft")
        #expect(KeyMapper.fromKeyCode(61) == "optionRight")
        #expect(KeyMapper.fromKeyCode(59) == "ctrlLeft")
        #expect(KeyMapper.fromKeyCode(63) == "fn")
    }

    /// The left and right variants of a modifier share one sound name.
    @Test func pairsOfModifiersShareASoundName() {
        #expect(KeyMapper.fromKeyCode(36) == KeyMapper.fromKeyCode(76))
        #expect(KeyMapper.fromKeyCode(54) == KeyMapper.fromKeyCode(55))
        #expect(KeyMapper.fromKeyCode(36) == "enter")
        #expect(KeyMapper.fromKeyCode(54) == "command")
    }

    @Test func unmappedKeyCodeFallsBackToDefault() {
        #expect(KeyMapper.fromKeyCode(9999) == KeyMapper.keyCodeNotFound)
        #expect(KeyMapper.keyCodeNotFound == "default")
    }

    @Test func negativeKeyCodeFallsBackToDefault() {
        #expect(KeyMapper.fromKeyCode(-1) == KeyMapper.keyCodeNotFound)
    }
}
