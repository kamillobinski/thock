import AppKit

/// How the chosen app list is applied to sound playback.
enum AppFilterMode: String, CaseIterable {
    /// Sounds play for every app.
    case off
    /// Sounds play only for apps in the list.
    case whitelist
    /// Sounds play for every app except those in the list.
    case blacklist
}

/// Keeps track of which app is in front so sounds can be limited to, or muted for, a
/// chosen list of apps.
///
/// `NSWorkspace` reports activations, so the frontmost bundle identifier is resolved
/// once per app switch and the per-keystroke check is a set lookup against a cached
/// list. The list is cached rather than read from `UserDefaults` on every keystroke
/// because each read would bridge a fresh array into Swift.
///
/// Everything here is read and written on the main thread: the event tap callbacks run
/// on the main run loop and the workspace notifications are delivered there, so no
/// locking is needed.
final class AppFilterService {
    static let shared = AppFilterService()

    private var frontmostBundleID: String?
    private var mode: AppFilterMode = .off
    private var chosenBundleIDs: Set<String> = []
    private var activationObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?

    private init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        reload()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication

            // Opening Thock's own settings window activates Thock, which must not count
            // as switching away from whatever the user was actually working in.
            guard app?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

            self.frontmostBundleID = app?.bundleIdentifier
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .appFilterDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reload()
        }
    }

    /// Whether sounds may play for the app that is currently in front.
    var isCurrentAppAllowed: Bool {
        guard mode != .off, !chosenBundleIDs.isEmpty else { return true }

        // With no frontmost app there is nothing to compare against, so stay out of the way.
        guard let bundleID = frontmostBundleID else { return true }

        let isChosen = chosenBundleIDs.contains(bundleID)
        return mode == .whitelist ? isChosen : !isChosen
    }

    /// Re-reads the persisted mode and list. Called on every app filter change.
    func reload() {
        mode = SettingsEngine.shared.getAppFilterMode()
        chosenBundleIDs = Set(SettingsEngine.shared.getAppFilterBundleIDs())
    }

    /// A human readable name for a bundle identifier, resolved through LaunchServices.
    static func displayName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }
}
