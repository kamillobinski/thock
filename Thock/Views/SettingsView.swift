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

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar with tabs
            HStack {
                Spacer()
                HStack(spacing: 0) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        ToolbarTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                Spacer()
            }
            .frame(height: 72)
            .background(Color(.controlBackgroundColor))
            
            Divider()
            
            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 500)
        .frame(minHeight: 300, maxHeight: .infinity)
    }
}

struct ToolbarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                    )
                
                Text(tab.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(width: 60, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("General settings will be available in future updates.")
                .foregroundColor(.secondary)
                .padding(30)
            
            Spacer()
        }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
            )
        }
    }
}

struct SettingsRowView: View {
    let title: String
    let subtitle: String?
    let control: AnyView
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SoundSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Sound settings will be available in future updates.")
                .foregroundColor(.secondary)
                .padding(30)
            
            Spacer()
        }
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Keyboard Section
            SettingsSectionView(title: "Global Shortcuts") {
                SettingsRowView(
                    title: "Toggle Thock on/off",
                    subtitle: "Quickly enable or disable Thock from anywhere",
                    control: AnyView(
                        KeyboardShortcuts.Recorder("", name: .toggleThock)
                    )
                )
            }
            
            Spacer()
        }
        .padding(30)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Thock")
                    .font(.title3.bold())
                
                Text("Version \(AppInfoHelper.appVersion)")
                    .foregroundColor(.secondary)
            }
            .padding(30)
            
            Spacer()
        }
    }
}

struct SettingsWindow: View {
    var body: some View {
        SettingsView()
    }
}
