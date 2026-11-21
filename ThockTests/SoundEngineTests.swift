import Testing
@testable import Thock

struct SoundEngineTests {
    @Test func neverRepeatsTheLastSoundWhenAnotherExists() {
        for _ in 0..<50 {
            #expect(SoundEngine.pickSound(from: ["a.wav", "b.wav"], avoiding: "a.wav") == "b.wav")
        }
    }

    @Test func repeatsWhenTheKeyHasOneSound() {
        #expect(SoundEngine.pickSound(from: ["a.wav"], avoiding: "a.wav") == "a.wav")
    }

    @Test func picksFromTheWholeListWithoutAPreviousSound() {
        let sounds = ["a.wav", "b.wav", "c.wav"]
        let picked = SoundEngine.pickSound(from: sounds, avoiding: nil)
        #expect(picked.map(sounds.contains) == true)
        #expect(SoundEngine.pickSound(from: [], avoiding: nil) == nil)
    }
}
