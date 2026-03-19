import Foundation

private let manifestURL = "https://raw.githubusercontent.com/kamillobinski/thock-soundpacks/refs/heads/main/manifest.json"

@MainActor
final class SoundpackRegistryService: ObservableObject {
    @Published var keyboardEntries: [SoundpackRegistryEntry] = []
    @Published var mouseEntries: [SoundpackRegistryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var downloadingIds: Set<UUID> = []
    @Published var installedIds: Set<UUID> = []
    @Published var customKeyboardSoundpacks: [Soundpack] = []
    @Published var customMouseSoundpacks: [Soundpack] = []
    
    init() {
        refreshInstalledIds()
    }
    
    func fetchManifest() async {
        isLoading = true
        errorMessage = nil
        
        do {
            guard let url = URL(string: manifestURL) else { throw URLError(.badURL) }
            let (data, _) = try await URLSession.shared.data(from: url)
            let manifest = try JSONDecoder().decode(SoundpackManifest.self, from: data)
            keyboardEntries = manifest.soundpacks.keyboard
            mouseEntries = manifest.soundpacks.mouse
            refreshInstalledIds()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        refreshCustomSoundpacks()
        isLoading = false
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    func install(_ entry: SoundpackRegistryEntry) async {
        guard !downloadingIds.contains(entry.id) else { return }
        downloadingIds.insert(entry.id)
        
        do {
            guard let downloadURL = URL(string: entry.download.url) else { throw URLError(.badURL) }
            
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
            
            let destination = customSoundsDirectory()
                .appendingPathComponent(entry.id.uuidString, isDirectory: true)
            
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-x", "-k", tempURL.path, destination.path]
            try process.run()
            process.waitUntilExit()
            
            try? FileManager.default.removeItem(at: tempURL)
            
            refreshInstalledIds()
            
            // Auto-select if this is the first soundpack of its category installed
            let db = SoundpackDatabase()
            let category = entry.category
            if db.getSoundpacks(for: category).count == 1,
               let soundpack = db.getSoundpack(by: entry.id) {
                if category == "mouse" {
                    SoundpackEngine.shared.applyMouse(soundpack: soundpack)
                } else {
                    SoundpackEngine.shared.applyKeyboard(soundpack: soundpack)
                }
            }
            
            NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
        } catch {
            print("Failed to install soundpack \(entry.metadata.name): \(error)")
        }
        
        downloadingIds.remove(entry.id)
    }
    
    func uninstall(_ entry: SoundpackRegistryEntry) {
        let folder = customSoundsDirectory().appendingPathComponent(entry.id.uuidString)
        try? FileManager.default.removeItem(at: folder)
        SoundpackEngine.shared.reloadAfterRemoval(for: entry.category)
        refreshInstalledIds()
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    func refreshInstalledIds() {
        let base = customSoundsDirectory()
        guard let subdirs = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil
        ) else {
            installedIds = []
            return
        }
        installedIds = Set(subdirs.compactMap { UUID(uuidString: $0.lastPathComponent) })
    }
    
    func refreshCustomSoundpacks() {
        let registryIds = Set(keyboardEntries.map(\.id) + mouseEntries.map(\.id))
        let allInstalled = SoundpackDatabase.loadInstalled()
        let custom = allInstalled.filter { !registryIds.contains($0.id) }
        customKeyboardSoundpacks = custom.filter { $0.category == "keyboard" }
        customMouseSoundpacks = custom.filter { $0.category == "mouse" }
    }
    
    func uninstallCustom(_ soundpack: Soundpack) {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock")
        let folder = base.appendingPathComponent(soundpack.path)
        try? FileManager.default.removeItem(at: folder)
        SoundpackEngine.shared.reloadAfterRemoval(for: soundpack.category)
        refreshInstalledIds()
        refreshCustomSoundpacks()
        NotificationCenter.default.post(name: .soundpackLibraryDidChange, object: nil)
    }
    
    private func customSoundsDirectory() -> URL {
        return CustomSoundpackHelper.getCustomSoundpackDirectory()
    }
}

extension Notification.Name {
    static let soundpackLibraryDidChange = Notification.Name("soundpackLibraryDidChange")
}
