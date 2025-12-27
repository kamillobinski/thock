import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: "Global") {
                    SettingsRowView(
                        title: "Toggle Thock",
                        subtitle: "Quickly enable or disable Thock from anywhere",
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
        .ignoresSafeArea(edges: .top)
    }
}

#Preview("Settings/Shortcuts") {
    ShortcutsSettingsView()
        .frame(width: 500, height: 600)
}
