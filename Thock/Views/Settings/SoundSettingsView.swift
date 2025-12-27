import SwiftUI

struct SoundSettingsView: View {
    @State private var disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
    @State private var ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
    @State private var autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
    @State private var idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
    @State private var audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
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
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: "Music Integration") {
                    SettingsRowView(
                        title: "Auto-mute with Music and Spotify",
                        subtitle: "Automatically mute sounds when music is playing",
                        control: AnyView(
                            Toggle("", isOn: $autoMuteOnMusicPlayback)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: autoMuteOnMusicPlayback) { newValue in
                                    SettingsEngine.shared.setAutoMuteOnMusicPlayback(newValue)
                                }
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: "Performance") {
                    SettingsRowView(
                        title: "Audio Latency",
                        subtitle: "- Ultra Low: most responsive, highest CPU usage\n- Low: very responsive, high CPU usage\n- Normal: balanced performance (recommended)\n- High: lower CPU usage, slight delay\n- Very High: lowest CPU usage, noticeable delay",
                        control: AnyView(
                            Picker("", selection: $audioBufferSize) {
                                Text("Ultra Low").tag(UInt32(64))
                                Text("Low").tag(UInt32(128))
                                Text("Normal").tag(UInt32(256))
                                Text("High").tag(UInt32(512))
                                Text("Very High").tag(UInt32(1024))
                            }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: audioBufferSize) { newValue in
                                    SettingsEngine.shared.setAudioBufferSize(newValue)
                                }
                        )
                    )
                    
                    SettingsRowView(
                        title: "Reduce CPU when idle",
                        subtitle: "Stops audio engine after inactivity to reduce CPU usage.\nFirst sound after idle may have a tiny delay.\nSet to 'Never' to keep engine always running.",
                        control: AnyView(
                            Picker("", selection: $idleTimeoutSeconds) {
                                Text("5 seconds").tag(5.0)
                                Text("10 seconds").tag(10.0)
                                Text("30 seconds").tag(30.0)
                                Text("1 minute").tag(60.0)
                                Text("5 minute").tag(300.0)
                                Text("Never").tag(0.0)
                            }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: idleTimeoutSeconds) { newValue in
                                    SettingsEngine.shared.setIdleTimeoutSeconds(newValue)
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
            disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
            ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
            autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
            idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
            audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
        }
    }
}

#Preview("Settings/Sound") {
    SoundSettingsView()
        .frame(width: 500, height: 600)
}
