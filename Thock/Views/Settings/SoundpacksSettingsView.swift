import SwiftUI

struct SoundpacksSettingsView: View {
    @StateObject private var service = SoundpackRegistryService()
    
    var body: some View {
        listView
            .task {
                await service.fetchManifest()
            }
            .onReceive(NotificationCenter.default.publisher(for: .soundpackLibraryDidChange)) { _ in
                service.refreshInstalledIds()
                service.refreshCustomSoundpacks()
            }
    }
    
    // MARK: - Subviews
    
    private var sortedKeyboardEntries: [SoundpackRegistryEntry] {
        service.keyboardEntries.sorted { service.installedIds.contains($0.id) && !service.installedIds.contains($1.id) }
    }
    
    private var sortedMouseEntries: [SoundpackRegistryEntry] {
        service.mouseEntries.sorted { service.installedIds.contains($0.id) && !service.installedIds.contains($1.id) }
    }
    
    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSectionView(title: L10n.explore) {
                    SettingsRowView(
                        title: L10n.soundpackDirectory,
                        subtitle: nil,
                        control: AnyView(
                            Button(action: {
                                CustomSoundpackHelper.openCustomSoundpackDirectory()
                            }) {
                                HStack(spacing: 4) {
                                    Text(L10n.open)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    Image(systemName: "arrow.up.forward")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                                .buttonStyle(.plain)
                        ),
                        isLast: false
                    )
                    SettingsLinkRowView(
                        title: L10n.soundpackCreationGuide,
                        url: "https://thockapp.com/docs/\(AppInfoHelper.appVersion)/features/custom-soundpacks",
                        showDivider: false
                    )
                }
                
                let installedKeyboard = sortedKeyboardEntries.filter { service.installedIds.contains($0.id) }
                let uninstalledKeyboard = sortedKeyboardEntries.filter { !service.installedIds.contains($0.id) }
                let customKeyboard = service.customKeyboardSoundpacks
                let keyboardRegistryEmpty = service.keyboardEntries.isEmpty
                let keyboardHasInlineState = keyboardRegistryEmpty && customKeyboard.isEmpty && (service.isLoading || service.errorMessage != nil)
                
                SettingsSectionView(title: L10n.keyboard, trailing: {
                    Button { Task { await service.fetchManifest() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isLoading)
                }) {
                    ForEach(Array(installedKeyboard.enumerated()), id: \.element.id) { index, entry in
                        SoundpackRegistryRowView(
                            entry: entry,
                            isInstalled: true,
                            isDownloading: service.downloadingIds.contains(entry.id),
                            isLast: false,
                            onInstall: { Task { await service.install(entry) } },
                            onUninstall: { service.uninstall(entry) }
                        )
                    }
                    ForEach(Array(customKeyboard.enumerated()), id: \.element.id) { index, soundpack in
                        SoundpackCustomRowView(
                            soundpack: soundpack,
                            isLast: index == customKeyboard.count - 1 && uninstalledKeyboard.isEmpty && !keyboardHasInlineState,
                            onUninstall: { service.uninstallCustom(soundpack) }
                        )
                    }
                    ForEach(Array(uninstalledKeyboard.enumerated()), id: \.element.id) { index, entry in
                        SoundpackRegistryRowView(
                            entry: entry,
                            isInstalled: false,
                            isDownloading: service.downloadingIds.contains(entry.id),
                            isLast: index == uninstalledKeyboard.count - 1,
                            onInstall: { Task { await service.install(entry) } },
                            onUninstall: { service.uninstall(entry) }
                        )
                    }
                    if keyboardRegistryEmpty && customKeyboard.isEmpty {
                        if service.isLoading {
                            SettingsRowView(
                                title: "Fetching soundpacks...",
                                subtitle: nil,
                                control: AnyView(ProgressView().controlSize(.small).scaleEffect(0.8)),
                                isLast: true
                            )
                        } else if service.errorMessage != nil {
                            SettingsRowView(
                                title: "Failed to load soundpacks",
                                subtitle: nil,
                                control: AnyView(
                                    Button("Retry") { Task { await service.fetchManifest() } }
                                        .controlSize(.small)
                                ),
                                isLast: true
                            )
                        } else {
                            SettingsRowView(
                                title: "No soundpacks available",
                                subtitle: nil,
                                control: AnyView(EmptyView()),
                                isLast: true
                            )
                        }
                    }
                }
                
                let installedMouse = sortedMouseEntries.filter { service.installedIds.contains($0.id) }
                let uninstalledMouse = sortedMouseEntries.filter { !service.installedIds.contains($0.id) }
                let customMouse = service.customMouseSoundpacks
                let mouseRegistryEmpty = service.mouseEntries.isEmpty
                let mouseHasInlineState = mouseRegistryEmpty && customMouse.isEmpty && (service.isLoading || service.errorMessage != nil)
                
                SettingsSectionView(title: L10n.mouse, trailing: {
                    Button { Task { await service.fetchManifest() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isLoading)
                }) {
                    ForEach(Array(installedMouse.enumerated()), id: \.element.id) { index, entry in
                        SoundpackRegistryRowView(
                            entry: entry,
                            isInstalled: true,
                            isDownloading: service.downloadingIds.contains(entry.id),
                            isLast: false,
                            onInstall: { Task { await service.install(entry) } },
                            onUninstall: { service.uninstall(entry) }
                        )
                    }
                    ForEach(Array(customMouse.enumerated()), id: \.element.id) { index, soundpack in
                        SoundpackCustomRowView(
                            soundpack: soundpack,
                            isLast: index == customMouse.count - 1 && uninstalledMouse.isEmpty && !mouseHasInlineState,
                            onUninstall: { service.uninstallCustom(soundpack) }
                        )
                    }
                    ForEach(Array(uninstalledMouse.enumerated()), id: \.element.id) { index, entry in
                        SoundpackRegistryRowView(
                            entry: entry,
                            isInstalled: false,
                            isDownloading: service.downloadingIds.contains(entry.id),
                            isLast: index == uninstalledMouse.count - 1,
                            onInstall: { Task { await service.install(entry) } },
                            onUninstall: { service.uninstall(entry) }
                        )
                    }
                    if mouseRegistryEmpty && customMouse.isEmpty {
                        if service.isLoading {
                            SettingsRowView(
                                title: "Fetching soundpacks...",
                                subtitle: nil,
                                control: AnyView(ProgressView().controlSize(.small).scaleEffect(0.8)),
                                isLast: true
                            )
                        } else if service.errorMessage != nil {
                            SettingsRowView(
                                title: "Failed to load soundpacks",
                                subtitle: nil,
                                control: AnyView(
                                    Button("Retry") { Task { await service.fetchManifest() } }
                                        .controlSize(.small)
                                ),
                                isLast: true
                            )
                        } else {
                            SettingsRowView(
                                title: "No soundpacks available",
                                subtitle: nil,
                                control: AnyView(EmptyView()),
                                isLast: true
                            )
                        }
                    }
                }
                
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Row View

private struct SoundpackRegistryRowView: View {
    let entry: SoundpackRegistryEntry
    let isInstalled: Bool
    let isDownloading: Bool
    let isLast: Bool
    let onInstall: () -> Void
    let onUninstall: () -> Void
    
    var body: some View {
        SettingsRowView(
            title: entry.metadata.name,
            subtitle: "\(entry.metadata.brand) · by \(entry.metadata.author) · \(formattedSize)",
            control: AnyView(actionControl),
            isLast: isLast
        )
    }
    
    private var formattedSize: String {
        let kb = Double(entry.download.size) / 1024
        if kb >= 1024 {
            return String(format: "%.1f MB", kb / 1024)
        }
        return String(format: "%.0f KB", kb)
    }
    
    @ViewBuilder
    private var actionControl: some View {
        if isDownloading {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .frame(width: 22, height: 22)
        } else if isInstalled {
            Button(action: onUninstall) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove soundpack")
        } else {
            Button(action: onInstall) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .help("Install soundpack")
        }
    }
}

// MARK: - Custom Row View

private struct SoundpackCustomRowView: View {
    let soundpack: Soundpack
    let isLast: Bool
    let onUninstall: () -> Void
    
    private var subtitle: String {
        var parts = ["Custom"]
        if !soundpack.brand.isEmpty { parts.append(soundpack.brand) }
        if !soundpack.author.isEmpty { parts.append("by \(soundpack.author)") }
        return parts.joined(separator: " · ")
    }
    
    var body: some View {
        SettingsRowView(
            title: soundpack.name,
            subtitle: subtitle,
            control: AnyView(
                Button(action: onUninstall) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                    .buttonStyle(.plain)
                    .help("Remove soundpack")
            ),
            isLast: isLast
        )
    }
}

#Preview("Settings/Soundpacks") {
    SoundpacksSettingsView()
        .frame(width: 500, height: 500)
}
