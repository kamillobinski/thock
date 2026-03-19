import SwiftUI

struct SoundpacksSettingsView: View {
    @StateObject private var service = SoundpackRegistryService()
    
    var body: some View {
        Group {
            if service.isLoading {
                loadingView
            } else if let error = service.errorMessage {
                errorView(error)
            } else if service.keyboardEntries.isEmpty && service.mouseEntries.isEmpty {
                emptyView
            } else {
                listView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -20)
        .task {
            await service.fetchManifest()
        }
        .onReceive(NotificationCenter.default.publisher(for: .soundpackLibraryDidChange)) { _ in
            service.refreshInstalledIds()
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading soundpacks...")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Failed to load soundpacks")
                .font(.system(size: 13, weight: .medium))
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Retry") {
                Task { await service.fetchManifest() }
            }
            .controlSize(.small)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No soundpacks available")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
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
                
                if !service.keyboardEntries.isEmpty {
                    SettingsSectionView(title: L10n.keyboard) {
                        ForEach(Array(service.keyboardEntries.enumerated()), id: \.element.id) { index, entry in
                            SoundpackRegistryRowView(
                                entry: entry,
                                isInstalled: service.installedIds.contains(entry.id),
                                isDownloading: service.downloadingIds.contains(entry.id),
                                isLast: index == service.keyboardEntries.count - 1,
                                onInstall: {
                                    Task { await service.install(entry) }
                                },
                                onUninstall: {
                                    service.uninstall(entry)
                                }
                            )
                        }
                    }
                }
                
                if !service.mouseEntries.isEmpty {
                    SettingsSectionView(title: L10n.mouse) {
                        ForEach(Array(service.mouseEntries.enumerated()), id: \.element.id) { index, entry in
                            SoundpackRegistryRowView(
                                entry: entry,
                                isInstalled: service.installedIds.contains(entry.id),
                                isDownloading: service.downloadingIds.contains(entry.id),
                                isLast: index == service.mouseEntries.count - 1,
                                onInstall: {
                                    Task { await service.install(entry) }
                                },
                                onUninstall: {
                                    service.uninstall(entry)
                                }
                            )
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Button {
                        Task { await service.fetchManifest() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(service.isLoading)
                }
                .padding(.top, 8)
                .padding(.horizontal, 10)
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

#Preview("Settings/Soundpacks") {
    SoundpacksSettingsView()
        .frame(width: 500, height: 500)
}
