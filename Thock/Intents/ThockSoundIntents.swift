import AppIntents
import AppKit
import Foundation

// MARK: - Shared Helper

/// AppIntents execute in a separate process (the Shortcuts/app-intents daemon),
/// not inside the running Thock menu-bar app. Mutating `AppEngine.shared` here
/// would only affect this throwaway process, so intents talk to the running app
/// through the `thock://` URL scheme (see `AppDelegate.application(_:open:)`).
/// Opening the URL also launches Thock if it isn't running.
enum ThockURLControl {
    static func send(_ action: String) throws {
        guard let url = URL(string: "thock://\(action)") else {
            throw ThockIntentError.invalidURL
        }
        if !NSWorkspace.shared.open(url) {
            throw ThockIntentError.appNotRunning
        }
    }
}

enum ThockIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidURL
    case appNotRunning

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidURL:
            return "Couldn't build the Thock control URL."
        case .appNotRunning:
            return "Thock doesn't seem to be installed or couldn't be opened."
        }
    }
}

// MARK: - Enable

struct EnableThockSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Thock Sounds"
    static var description = IntentDescription("Turn on Thock keyboard sounds.")
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ThockURLControl.send("enable")
        return .result(dialog: "Thock sounds enabled.")
    }
}

// MARK: - Disable

struct DisableThockSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Thock Sounds"
    static var description = IntentDescription("Turn off Thock keyboard sounds.")
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ThockURLControl.send("disable")
        return .result(dialog: "Thock sounds disabled.")
    }
}

// MARK: - Toggle

struct ToggleThockSoundsIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Thock Sounds"
    static var description = IntentDescription("Toggle Thock keyboard sounds on or off.")
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ThockURLControl.send("toggle")
        return .result(dialog: "Thock sounds toggled.")
    }
}

// MARK: - App Shortcuts

struct ThockAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EnableThockSoundsIntent(),
            phrases: [
                "Turn on Thock sounds",
                "Enable Thock sounds",
                "Start Thock sounds"
            ],
            shortTitle: "Enable Sounds",
            systemImageName: "speaker.wave.2.fill"
        )
        AppShortcut(
            intent: DisableThockSoundsIntent(),
            phrases: [
                "Turn off Thock sounds",
                "Disable Thock sounds",
                "Stop Thock sounds",
                "Mute Thock sounds"
            ],
            shortTitle: "Disable Sounds",
            systemImageName: "speaker.slash.fill"
        )
        AppShortcut(
            intent: ToggleThockSoundsIntent(),
            phrases: [
                "Toggle Thock sounds"
            ],
            shortTitle: "Toggle Sounds",
            systemImageName: "speaker.wave.2"
        )
    }
}
