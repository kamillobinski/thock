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
    @State private var openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
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
                    )
                )
            }
            
            Spacer()
        }
        .padding(.top, 30)
        .ignoresSafeArea(edges: .top)
        .padding([.leading, .trailing, .bottom], 30)
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
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
    @State private var disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
    @State private var ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
    @State private var autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            SettingsSectionView(title: "Filters") {
                SettingsRowView(
                    title: "Disable sound for modifier keys",
                    subtitle: "Mute sounds when pressing modifier keys (Cmd, Shift, etc.)",
                    control: AnyView(
                        Toggle("", isOn: $disableModifierKeys)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: disableModifierKeys) { newValue in
                                SettingsEngine.shared.setModifierKeySound(newValue)
                            }
                    )
                )
                
                SettingsRowView(
                    title: "Ignore rapid key events",
                    subtitle: "Filter out key events that occur too quickly in succession",
                    control: AnyView(
                        Toggle("", isOn: $ignoreRapidKeyEvents)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: ignoreRapidKeyEvents) { newValue in
                                SettingsEngine.shared.setIgnoreRapidKeyEvents(newValue)
                            }
                    )
                )
            }
            
            SettingsSectionView(title: "Music Integration") {
                SettingsRowView(
                    title: "Auto-mute with Music and Spotify",
                    subtitle: "Automatically mute keyboard sounds when music is playing",
                    control: AnyView(
                        Toggle("", isOn: $autoMuteOnMusicPlayback)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: autoMuteOnMusicPlayback) { newValue in
                                SettingsEngine.shared.setAutoMuteOnMusicPlayback(newValue)
                            }
                    )
                )
            }
            
            Spacer()
        }
        .padding(.top, 30)
        .ignoresSafeArea(edges: .top)
        .padding([.leading, .trailing, .bottom], 30)
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
            ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
            autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
        }
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Keyboard Section
            SettingsSectionView(title: "Global Shortcuts") {
                SettingsRowView(
                    title: "Toggle Thock",
                    subtitle: "Quickly enable or disable Thock from anywhere",
                    control: AnyView(
                        KeyboardShortcuts.Recorder("", name: .toggleThock)
                    )
                )
            }
            
            Spacer()
        }
        .padding(.top, 30)
        .ignoresSafeArea(edges: .top)
        .padding([.leading, .trailing, .bottom], 30)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Image("SettingsBanner")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .cornerRadius(8)
                .padding(.horizontal, 30)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Version \(AppInfoHelper.appVersion)")
                    .foregroundColor(.secondary)
            }
            .padding([.leading, .trailing, .bottom], 30)
            
            Spacer()
        }
        .padding(.top, 30)
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - View Modifiers

struct SidebarModifier: ViewModifier {
    func body(content: Content) -> some View {
        // Temporarily forcing macOS 13 behavior for testing
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
                    Label(tab.rawValue, systemImage: tab.icon)
                }
            }
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
