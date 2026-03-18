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
        
        isLoading = false
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
        
        SoundpackManager.shared.reloadCurrentSoundpacks()
        
        let category = entry.category
        if category == "mouse" {
            if let fallback = SoundpackManager.shared.getCurrentMouseSoundpack() {
                SoundpackEngine.shared.applyMouse(soundpack: fallback)
            }
        } else {
            if let fallback = SoundpackManager.shared.getCurrentKeyboardSoundpack() {
                SoundpackEngine.shared.applyKeyboard(soundpack: fallback)
            }
        }
        
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
    
    private func customSoundsDirectory() -> URL {
        return CustomSoundpackHelper.getCustomSoundpackDirectory()
    }
}

extension Notification.Name {
    static let soundpackLibraryDidChange = Notification.Name("soundpackLibraryDidChange")
}
