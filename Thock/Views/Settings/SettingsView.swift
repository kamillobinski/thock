import SwiftUI
import KeyboardShortcuts

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case sound = "Sound"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .sound: return "speaker.wave.2.fill"
        case .shortcuts: return "command"
        case .about: return "info.circle.fill"
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
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    SidebarRowView(tab: tab, isSelected: selectedTab == tab)
                }
            }
            .listStyle(.sidebar)
            .listItemTint(.clear)
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
            case .about:
                AboutSettingsView()
            }
        }
        .frame(minWidth: 715, maxWidth: 715, minHeight: 470, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 0, height: 0)
            }
        }
    }
}

#Preview("Settings") {
    SettingsView()
}
