import Foundation

@main struct RecoveryGuardTests {
    static var passed = 0
    static func check(_ value: @autoclosure () -> Bool, _ name: String) {
        guard value() else { fatalError("FAIL: \(name)") }
        passed += 1
        print("PASS: \(name)")
    }
    static func finish(_ guardState: PlaybackRecoveryGuard, _ probe: PlaybackRecoveryGuard.Probe,
                       generation: UInt64 = 1, running: Bool = true, pending: Bool = true,
                       available: Bool = true, now: TimeInterval = 2) -> Bool {
        guardState.authorizeRecovery(probe, generation: generation, expectedRunning: running,
                                    hasPendingSounds: pending, deviceAvailable: available, now: now)
    }
    static func main() {
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            state.recordCallback()
            check(!finish(state, probe), "callback progress prevents recovery even with pending sounds")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(finish(state, probe), "sustained callback starvation with playback demand authorizes recovery")
            check(!finish(state, probe), "one probe cannot recover twice")
            check(state.beginProbe(generation: 2, now: 11.99) == nil, "cooldown prevents reset loops")
            check(state.beginProbe(generation: 2, now: 12) != nil, "new playback demand can retry after cooldown")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(!finish(state, probe, pending: false), "silence with no pending sounds never recovers")
            check(state.snapshot().recoveries == 0, "silence consumes no recovery attempt")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(!finish(state, probe, running: false), "intentionally stopped or unready queue never recovers")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(!finish(state, probe, available: false), "disconnected selected output never triggers recovery")
            let next = state.beginProbe(generation: 1, now: 2)!
            check(finish(state, next, now: 3), "device absence does not consume cooldown")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(!finish(state, probe, generation: 2), "device switch or wake invalidates old-generation check")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let old = state.beginProbe(generation: 1, now: 0)!
            state.invalidate()
            let current = state.beginProbe(generation: 1, now: 1)!
            check(!finish(state, old, now: 2), "cancelled old check cannot act on new probe")
            check(finish(state, current, now: 2), "cancelled check cannot cancel replacement probe")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let probe = state.beginProbe(generation: 1, now: 0)!
            check(!finish(state, probe, now: 0.99), "recovery requires full observation interval")
        }
        do {
            let state = PlaybackRecoveryGuard()
            let lock = NSLock()
            var probes: [PlaybackRecoveryGuard.Probe] = []
            DispatchQueue.concurrentPerform(iterations: 100) { _ in
                if let p = state.beginProbe(generation: 1, now: 0) {
                    lock.lock(); probes.append(p); lock.unlock()
                }
            }
            check(probes.count == 1, "100 concurrent playback requests coalesce into one probe")
            DispatchQueue.concurrentPerform(iterations: 100) { _ in state.recordCallback() }
            check(state.snapshot().callbacks == 100, "concurrent callbacks are counted safely")
            check(!finish(state, probes[0]), "concurrent callback progress cancels recovery")
        }
        print("ALL \(passed) RECOVERY GUARD CHECKS PASSED")
    }
}
