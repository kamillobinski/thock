import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Lets the user pick which apps Thock plays sounds for.
struct AppFilterSettingsView: View {
    @State private var mode = SettingsEngine.shared.getAppFilterMode()
    @State private var chosenBundleIDs: [String] = SettingsEngine.shared.getAppFilterBundleIDs()
    @State private var refreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Spacer()
                    .frame(height: 40)

                SettingsSectionView(title: L10n.appFilter) {
                    SettingsRowView(
                        title: L10n.appFilterDescription,
                        subtitle: nil,
                        control: AnyView(
                            Picker(L10n.appFilterDescription, selection: $mode) {
                                Text(L10n.appFilterOff).tag(AppFilterMode.off)
                                Text(L10n.appFilterWhitelist).tag(AppFilterMode.whitelist)
                                Text(L10n.appFilterBlacklist).tag(AppFilterMode.blacklist)
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                            .labelsHidden()
                            .frame(width: 220)
                            .onChange(of: mode) { newMode in
                                SettingsEngine.shared.setAppFilterMode(newMode)
                            }
                        ),
                        isLast: true
                    )
                }

                if mode != .off {
                    SettingsSectionView(title: L10n.appFilterChosenApps) {
                        if chosenBundleIDs.isEmpty {
                            SettingsRowView(
                                title: L10n.appFilterEmpty,
                                subtitle: nil,
                                control: AnyView(EmptyView()),
                                isLast: true
                            )
                        } else {
                            ForEach(Array(chosenBundleIDs.enumerated()), id: \.element) { index, bundleID in
                                choseAppRow(
                                    bundleID: bundleID,
                                    isLast: index == chosenBundleIDs.count - 1
                                )
                            }
                        }
                    }

                    Button(L10n.appFilterAdd) {
                        presentAppPicker()
                    }
                    .controlSize(.small)
                    .padding(.top, 10)
                    .padding(.leading, 6)
                }

                Spacer()
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .id(refreshID)
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .appFilterDidChange)) { _ in
            mode = SettingsEngine.shared.getAppFilterMode()
            chosenBundleIDs = SettingsEngine.shared.getAppFilterBundleIDs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }

    @ViewBuilder
    private func choseAppRow(bundleID: String, isLast: Bool) -> some View {
        SettingsRowView(
            title: AppFilterService.displayName(for: bundleID),
            subtitle: nil,
            control: AnyView(
                Button {
                    SettingsEngine.shared.removeAppFilterBundleID(bundleID)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(L10n.appFilterRemove)
                .accessibilityLabel("\(L10n.appFilterRemove): \(AppFilterService.displayName(for: bundleID))")
            ),
            isLast: isLast
        )
    }

    private func presentAppPicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = L10n.appFilterAdd

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else { continue }
            SettingsEngine.shared.addAppFilterBundleID(bundleID)
        }
    }
}

#Preview("Settings/App Filter") {
    AppFilterSettingsView()
        .frame(width: 500, height: 600)
}
