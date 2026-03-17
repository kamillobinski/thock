import SwiftUI

struct UtilitiesSettingsView: View {
    @State private var isCleaningMode = SettingsEngine.shared.isCleaningModeEnabled()
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: L10n.keyboardCleaning) {
                    SettingsRowView(
                        title: L10n.blockKeyboardInput,
                        subtitle: L10n.keyboardCleaningSubtitle,
                        control: AnyView(
                            Toggle("", isOn: $isCleaningMode)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: isCleaningMode) { newValue in
                                    SettingsEngine.shared.setCleaningMode(newValue)
                                }
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
        .onReceive(NotificationCenter.default.publisher(for: .cleaningModeDidChange)) { _ in
            isCleaningMode = SettingsEngine.shared.isCleaningModeEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview("Settings/Utilities") {
    UtilitiesSettingsView()
        .frame(width: 500, height: 600)
}
