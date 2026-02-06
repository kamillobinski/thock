import SwiftUI

struct GeneralSettingsView: View {
    @State private var openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 40)
                    
                    // App Icon
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 84, height: 84)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    }
                    
                    Spacer().frame(height: 8)
                    
                    // App Name
                    Text(AppInfoHelper.appName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                        .frame(height: 3)
                    
                    // Version
                    Text("\(L10n.version) \(AppInfoHelper.appVersion)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                        .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
                
                SettingsSectionView(title: L10n.system) {
                    SettingsRowView(
                        title: L10n.launchAtLogin,
                        subtitle: L10n.launchAtLoginSubtitle,
                        control: AnyView(
                            Toggle("", isOn: $openAtLogin)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: openAtLogin) { newValue in
                                    SettingsEngine.shared.setOpenAtLogin(newValue)
                                }
                        )
                    )
                    
                    SettingsRowView(
                        title: L10n.language,
                        subtitle: L10n.languageSubtitle,
                        control: AnyView(
                            Picker("", selection: $localization.current) {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .controlSize(.small)
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: L10n.more) {
                    SettingsLinkRowView(
                        title: L10n.aboutThisVersion,
                        url: "https://github.com/kamillobinski/thock/releases/tag/\(AppInfoHelper.appVersion)"
                    )
                    
                    SettingsLinkRowView(
                        title: L10n.contribute,
                        url: "https://github.com/kamillobinski/thock"
                    )
                    
                    SettingsLinkRowView(
                        title: L10n.reportBug,
                        url: "https://github.com/kamillobinski/thock/issues",
                        showDivider: false
                    )
                }
                
                Spacer()
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .id(refreshID)
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview("Settings/General") {
    GeneralSettingsView()
        .frame(width: 500, height: 600)
}
