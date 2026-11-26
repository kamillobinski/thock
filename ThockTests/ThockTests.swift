//
//  ThockTests.swift
//  ThockTests
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import Foundation
import Testing
@testable import Thock

struct ThockTests {
    @Test @MainActor func microphoneAutoMuteFollowsActivityAndSetting() async throws {
        let settings = SettingsEngine.shared
        let original = settings.isAutoMuteOnMicrophoneUseEnabled()
        defer { settings.setAutoMuteOnMicrophoneUse(original) }
        settings.setAutoMuteOnMicrophoneUse(false)

        let lock = NSLock()
        var active = true
        let monitor = MicrophoneMonitor {
            #expect(!Thread.isMainThread)
            return lock.withLock { active }
        }
        #expect(!monitor.shouldMute)

        settings.setAutoMuteOnMicrophoneUse(true)
        #expect(SettingsManager.shared.autoMuteOnMicrophoneUse)
        if #unavailable(macOS 14.0) {
            #expect(!monitor.shouldMute)
            #expect(!MicrophoneMonitor.isMicrophoneInUse())
            return
        }
        try await expectMute(true, monitor: monitor)

        lock.withLock { active = false }
        try await expectMute(false, monitor: monitor)

        lock.withLock { active = true }
        try await expectMute(true, monitor: monitor)

        settings.setAutoMuteOnMicrophoneUse(false)
        try await expectMute(false, monitor: monitor)
        try await Task.sleep(for: .milliseconds(250))
        #expect(!monitor.shouldMute)
    }

    private func expectMute(_ expected: Bool, monitor: MicrophoneMonitor) async throws {
        let deadline = ContinuousClock.now + .seconds(2)
        while monitor.shouldMute != expected && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(monitor.shouldMute == expected)
    }
}
