import Foundation
import CoreAudio

/// Reads audio activity metadata without opening or recording the microphone.
final class MicrophoneMonitor {
    static let shared = MicrophoneMonitor()

    private let activity: () -> Bool
    private let queue = DispatchQueue(label: "Thock.MicrophoneMonitor", qos: .utility)
    private let lock = NSLock()
    private var microphoneInUse = false
    private var timer: DispatchSourceTimer?

    var shouldMute: Bool {
        lock.withLock { microphoneInUse }
    }

    init(activity: @escaping () -> Bool = MicrophoneMonitor.isMicrophoneInUse) {
        self.activity = activity
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateMonitoring), name: .settingsDidChange, object: nil
        )
        updateMonitoring()
    }

    deinit {
        timer?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func updateMonitoring() {
        queue.async { [weak self] in self?.updateTimer() }
    }

    private func updateTimer() {
        guard #available(macOS 14.0, *), SettingsEngine.shared.isAutoMuteOnMicrophoneUseEnabled() else {
            timer?.cancel()
            timer = nil
            lock.withLock { microphoneInUse = false }
            return
        }
        guard timer == nil else { return }

        // Running-input property notifications are unreliable on some macOS versions.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(200), leeway: .milliseconds(20))
        timer.setEventHandler { [weak self] in self?.refresh() }
        self.timer = timer
        timer.resume()
    }

    private func refresh() {
        let active = activity()
        lock.withLock { microphoneInUse = active }
    }

    static func isMicrophoneInUse() -> Bool {
        guard #available(macOS 14.0, *) else { return false }
        let system = AudioObjectID(kAudioObjectSystemObject)
        return objectIDs(system, selector: kAudioHardwarePropertyProcessObjectList).contains { process in
            uint32Property(process, selector: kAudioProcessPropertyIsRunningInput) == 1
                && !isExcluded(process)
        }
    }

    @available(macOS 14.0, *)
    private static func isExcluded(_ process: AudioObjectID) -> Bool {
        let pid = pid_t(bitPattern: uint32Property(process, selector: kAudioProcessPropertyPID) ?? 0)
        if pid == getpid() { return true }

        var address = propertyAddress(kAudioProcessPropertyBundleID)
        var bundleID: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: bundleID))
        if AudioObjectGetPropertyData(process, &address, 0, nil, &size, &bundleID) == noErr,
           let identifier = bundleID?.takeRetainedValue() as String?,
           identifier == "com.apple.corespeechd" || identifier == "com.apple.corespeechd_system" {
            return true
        }

        // System daemons can appear in CoreAudio without a bundle identifier.
        guard pid > 0 else { return false }
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return false }
        let executable = String(cString: path)
        return executable.hasPrefix("/System/Library/PrivateFrameworks/CoreSpeech.framework/")
            && (executable.hasSuffix("/corespeechd") || executable.hasSuffix("/corespeechd_system"))
    }

    private static func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func objectIDs(
        _ object: AudioObjectID, selector: AudioObjectPropertySelector
    ) -> [AudioObjectID] {
        var address = propertyAddress(selector)
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

    private static func uint32Property(
        _ object: AudioObjectID, selector: AudioObjectPropertySelector
    ) -> UInt32? {
        var address = propertyAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }
}
