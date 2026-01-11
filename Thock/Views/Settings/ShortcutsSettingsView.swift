import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: L10n.global) {
                    SettingsRowView(
                        title: L10n.toggleThock,
                        subtitle: L10n.toggleThockSubtitle,
                        control: AnyView(
                            KeyboardShortcuts.Recorder("", name: .toggleThock)
                        ),
                        isLast: true
                    )
                }
                
                Spacer()
            }
            .padding([.leading, .trailing, .bottom], 20)
        }
        .id(refreshID)
        .ignoresSafeArea(edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview("Settings/Shortcuts") {
    ShortcutsSettingsView()
        .frame(width: 500, height: 600)
}

