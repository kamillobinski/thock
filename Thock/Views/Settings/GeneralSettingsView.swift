import SwiftUI

struct GeneralSettingsView: View {
    @State private var openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
    
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
                    Text("Version \(AppInfoHelper.appVersion)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                        .frame(height: 30)
                }
                .frame(maxWidth: .infinity)
                
                SettingsSectionView(title: "System") {
                    SettingsRowView(
                        title: "Launch Thock at login",
                        subtitle: "Automatically start Thock when you log in",
                        control: AnyView(
                            Toggle("", isOn: $openAtLogin)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: openAtLogin) { newValue in
                                    SettingsEngine.shared.setOpenAtLogin(newValue)
                                }
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: "More") {
                    SettingsLinkRowView(
                        title: "About this version",
                        url: "https://github.com/kamillobinski/thock/releases/tag/\(AppInfoHelper.appVersion)"
                    )
                    
                    SettingsLinkRowView(
                        title: "Contribute",
                        url: "https://github.com/kamillobinski/thock"
                    )
                    
                    SettingsLinkRowView(
                        title: "Report a bug",
                        url: "https://github.com/kamillobinski/thock/issues",
                        showDivider: false
                    )
                }
                
                Spacer()
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
        }
    }
}

#Preview("Settings/General") {
    GeneralSettingsView()
        .frame(width: 500, height: 600)
}
