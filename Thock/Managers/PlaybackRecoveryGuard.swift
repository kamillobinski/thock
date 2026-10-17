import Foundation

/// A playback request arms one delayed check. Silence alone never arms recovery.
/// Callbacks only increment a counter; they never touch queue lifecycle state.
final class PlaybackRecoveryGuard {
    struct Probe: Equatable {
        let id: UInt64
        let generation: UInt64
        let callbackCount: UInt64
        let startedAt: TimeInterval
    }

    let observationInterval: TimeInterval
    private let cooldown: TimeInterval
    private let lock = NSLock()
    private var callbacks: UInt64 = 0
    private var nextID: UInt64 = 0
    private var pending: Probe?
    private var lastRecovery: TimeInterval?
    private var recoveries: UInt64 = 0

    init(observationInterval: TimeInterval = 1.0, cooldown: TimeInterval = 10.0) {
        self.observationInterval = observationInterval
        self.cooldown = cooldown
    }

    func recordCallback() {
        lock.lock()
        callbacks &+= 1
        lock.unlock()
    }

    func beginProbe(generation: UInt64, now: TimeInterval) -> Probe? {
        lock.lock()
        defer { lock.unlock() }
        guard pending == nil, outsideCooldown(now) else { return nil }
        nextID &+= 1
        let probe = Probe(id: nextID, generation: generation, callbackCount: callbacks, startedAt: now)
        pending = probe
        return probe
    }

    /// Called after the observation delay, with queue lifetime protected by the caller.
    func authorizeRecovery(_ probe: Probe, generation: UInt64, expectedRunning: Bool,
                           hasPendingSounds: Bool, deviceAvailable: Bool, now: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard pending == probe else { return false }
        pending = nil
        guard probe.generation == generation, expectedRunning, hasPendingSounds,
              deviceAvailable, callbacks == probe.callbackCount,
              now - probe.startedAt >= observationInterval, outsideCooldown(now) else { return false }
        lastRecovery = now
        recoveries &+= 1
        return true
    }

    func invalidate() {
        lock.lock()
        pending = nil
        lock.unlock()
    }

    func snapshot() -> (callbacks: UInt64, recoveries: UInt64) {
        lock.lock()
        defer { lock.unlock() }
        return (callbacks, recoveries)
    }

    private func outsideCooldown(_ now: TimeInterval) -> Bool {
        guard let lastRecovery else { return true }
        return now - lastRecovery >= cooldown
    }
}
