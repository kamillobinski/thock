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

        var active = true
        let monitor = MicrophoneMonitor(activity: { active })
        #expect(!monitor.shouldMute)

        settings.setAutoMuteOnMicrophoneUse(true)
        #expect(SettingsManager.shared.autoMuteOnMicrophoneUse)
        #expect(monitor.shouldMute)

        active = false
        try await Task.sleep(for: .milliseconds(350))
        #expect(!monitor.shouldMute)

        active = true
        try await Task.sleep(for: .milliseconds(350))
        #expect(monitor.shouldMute)

        settings.setAutoMuteOnMicrophoneUse(false)
        #expect(!monitor.shouldMute)
        try await Task.sleep(for: .milliseconds(350))
        #expect(!monitor.shouldMute)
    }
}
