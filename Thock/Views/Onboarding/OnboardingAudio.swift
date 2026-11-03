import Foundation
import ApplicationServices
import Network

@available(macOS 14.0, *)
@MainActor
@Observable
final class OnboardingAudio {
    static let shared = OnboardingAudio()
    static let defaultSoundpackId = UUID(uuidString: "c9f8ec9f-4fe0-414b-87ac-4d5b64be84e0")!

    enum Status {
        case preparing, ready, unavailable
    }

    private(set) var status: Status = .preparing
    private(set) var currentSoundpackId: UUID?
    private(set) var isSystemTrackingActive = AXIsProcessTrusted()
    private(set) var pendingDownloadBytes: Int?
    @ObservationIgnored let registry = SoundpackRegistryService()
    @ObservationIgnored private var prepareTask: Task<Void, Never>?
    @ObservationIgnored private var trackingObserver: NSObjectProtocol?
    @ObservationIgnored private let pathMonitor = NWPathMonitor()

    private init() {
        syncCurrentSoundpack()
        trackingObserver = NotificationCenter.default.addObserver(
            forName: .keyboardTrackingDidStart, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isSystemTrackingActive = true }
        }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in self?.retry() }
        }
        pathMonitor.start(queue: .main)
    }

    private var simulatesOffline: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "onboardingSimulateOffline")
        #else
        return false
        #endif
    }

    func prepare() {
        guard prepareTask == nil else { return }
        prepareTask = Task { [weak self] in
            await self?.run()
            self?.prepareTask = nil
        }
    }

    func retry() {
        guard status == .unavailable else { return }
        status = .preparing
        prepare()
    }

    private func run() async {
        if simulatesOffline {
            status = .unavailable
            return
        }
        if hasUsableKeyboardSoundpack() {
            status = .ready
        }
        await registry.fetchManifest()
        let entries = registry.keyboardEntries
        if !hasUsableKeyboardSoundpack(),
           let entry = entries.first(where: { $0.id == Self.defaultSoundpackId }) ?? entries.first {
            pendingDownloadBytes = entry.download.size
            await registry.install(entry)
            pendingDownloadBytes = nil
            if !hasUsableKeyboardSoundpack(),
               let pack = SoundpackDatabase().getSoundpack(by: entry.id) {
                SettingsEngine.shared.selectKeyboardSoundpack(pack)
            }
        }
        syncCurrentSoundpack()
        status = hasUsableKeyboardSoundpack() ? .ready : .unavailable
    }

    func syncCurrentSoundpack() {
        currentSoundpackId = SoundpackEngine.shared.getCurrentKeyboardSoundpack()?.id
    }

    private func hasUsableKeyboardSoundpack() -> Bool {
        guard let current = SoundpackEngine.shared.getCurrentKeyboardSoundpack() else { return false }
        return SoundpackDatabase().getSoundpack(by: current.id) != nil
    }

    func installedKeyboardSoundpacks() -> [Soundpack] {
        SoundpackDatabase().getSoundpacks(for: "keyboard").sorted { $0.name < $1.name }
    }

    func select(_ soundpack: Soundpack) {
        defer {
            if status != .ready, hasUsableKeyboardSoundpack() { status = .ready }
        }
        guard SoundpackEngine.shared.getCurrentKeyboardSoundpack()?.id != soundpack.id else {
            currentSoundpackId = soundpack.id
            return
        }
        currentSoundpackId = soundpack.id
        SettingsEngine.shared.selectKeyboardSoundpack(soundpack)
    }

    func install(_ entry: SoundpackRegistryEntry) async -> Soundpack? {
        await registry.install(entry)
        return SoundpackDatabase().getSoundpack(by: entry.id)
    }

    func playKey(_ keyCode: Int64, down: Bool, synthetic: Bool, layout: KeyLayout.Physical = .ansi) {
        guard synthetic || !isSystemTrackingActive else { return }
        SoundManager.playbackQueue.async {
            SoundEngine.shared.play(for: keyCode, isKeyDown: down, layout: layout)
        }
    }
}
