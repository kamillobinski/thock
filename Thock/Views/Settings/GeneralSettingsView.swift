import SwiftUI

struct GeneralSettingsView: View {
    @State private var openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: "Startup") {
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
