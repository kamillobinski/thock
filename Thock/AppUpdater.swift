import Foundation
import Sparkle

final class AppUpdater: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    static let shared = AppUpdater()

    var onUpdateAvailabilityChange: ((Bool) -> Void)?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    private override init() {
        super.init()
    }

    func start() {
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        setUpdateAvailable(true)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        setUpdateAvailable(false)
    }

    // MARK: - SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillFinishUpdateSession() {
        setUpdateAvailable(false)
    }

    private func setUpdateAvailable(_ isAvailable: Bool) {
        DispatchQueue.main.async {
            self.onUpdateAvailabilityChange?(isAvailable)
        }
    }
}
