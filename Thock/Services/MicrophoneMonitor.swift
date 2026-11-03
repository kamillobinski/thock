import Foundation
import CoreAudio

/// Reads audio activity metadata without opening or recording the microphone.
final class MicrophoneMonitor {
    static let shared = MicrophoneMonitor()

    private let activity: () -> Bool
    private let lock = NSLock()
    private var microphoneInUse = false
    private var timer: Timer?

    var shouldMute: Bool {
        lock.lock()
        defer { lock.unlock() }
        return microphoneInUse
    }

    init(activity: @escaping () -> Bool = MicrophoneMonitor.isMicrophoneInUse) {
        self.activity = activity
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateMonitoring), name: .settingsDidChange, object: nil
        )
        updateMonitoring()
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateMonitoring() {
        guard #available(macOS 14.0, *), SettingsEngine.shared.isAutoMuteOnMicrophoneUseEnabled() else {
            timer?.invalidate()
            timer = nil
            setMicrophoneInUse(false)
            return
        }
        refresh()
        guard timer == nil else { return }
        // Poll because running-input property notifications are unreliable on some macOS versions.
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        setMicrophoneInUse(activity())
    }

    private func setMicrophoneInUse(_ active: Bool) {
        lock.lock()
        microphoneInUse = active
        lock.unlock()
    }

    static func isMicrophoneInUse() -> Bool {
        guard #available(macOS 14.0, *) else { return false }
        let system = AudioObjectID(kAudioObjectSystemObject)
        return objectIDs(system, selector: kAudioHardwarePropertyProcessObjectList).contains {
            isRunning($0, selector: kAudioProcessPropertyIsRunningInput)
        }
    }

    private static func objectIDs(
        _ object: AudioObjectID, selector: AudioObjectPropertySelector
    ) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = ids.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0.baseAddress!)
        }
        return status == noErr ? Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size)) : []
    }

    private static func isRunning(_ object: AudioObjectID, selector: AudioObjectPropertySelector) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr && value != 0
    }
}
