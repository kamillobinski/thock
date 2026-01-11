import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable {
    case general
    case sound
    case shortcuts
    
    var localizedName: String {
        switch self {
        case .general: return L10n.general
        case .sound: return L10n.sound
        case .shortcuts: return L10n.shortcuts
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .sound: return "speaker.wave.2.fill"
        case .shortcuts: return "command"
        }
    }
}

struct SidebarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.toolbar(removing: .sidebarToggle)
        } else {
            content
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    SidebarRowView(tab: tab, isSelected: selectedTab == tab)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 215)
            .modifier(SidebarModifier())
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
            case .sound:
                SoundSettingsView()
            case .shortcuts:
                ShortcutsSettingsView()
            }
        }
        .id(refreshID)
        .frame(minWidth: 715, maxWidth: 715, minHeight: 470, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

#Preview("Settings") {
    SettingsView()
}

