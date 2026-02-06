import SwiftUI

struct SoundSettingsView: View {
    @State private var volume = Double(SettingsEngine.shared.getVolume())
    @State private var disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
    @State private var ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
    @State private var autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
    @State private var idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
    @State private var audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
    @State private var availableDevices: [AudioDeviceManager.AudioDevice] = []
    @State private var selectedDeviceUID: String = SettingsEngine.shared.getSelectedAudioDeviceUID() ?? "system-default"
    @State private var mouseSoundEnabled = SettingsEngine.shared.isMouseSoundEnabled()
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: L10n.output) {
                    SettingsRowView(
                        title: L10n.volume,
                        subtitle: nil,
                        control: AnyView(
                            HStack(spacing: 8) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                
                                Slider(value: $volume, in: 0...1, step: 0.125)
                                    .frame(width: 240)
                                    .onChange(of: volume) { newValue in
                                        SettingsEngine.shared.setVolume(Float(newValue))
                                    }
                                
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        )
                    )
                    
                    SettingsRowView(
                        title: L10n.playThrough,
                        subtitle: nil,
                        control: AnyView(
                            Picker("", selection: $selectedDeviceUID) {
                                Text(L10n.systemDefault).tag("system-default")
                                
                                if !availableDevices.isEmpty {
                                    Divider()
                                }
                                
                                ForEach(availableDevices) { device in
                                    Text(device.name).tag(device.id)
                                }
                            }
                                .pickerStyle(.menu)
                                .controlSize(.small)
                                .frame(width: 200, alignment: .trailing)
                                .onChange(of: selectedDeviceUID) { newValue in
                                    let uidToSave = newValue == "system-default" ? nil : newValue
                                    SettingsEngine.shared.setSelectedAudioDeviceUID(uidToSave)
                                }
                        )
                    )
                    
                    SettingsRowView(
                        title: L10n.mouseClickSound,
                        subtitle: nil,
                        control: AnyView(
                            Toggle("", isOn: $mouseSoundEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: mouseSoundEnabled) { newValue in
                                    SettingsEngine.shared.setMouseSoundEnabled(newValue)
                                }
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: L10n.filters) {
                    SettingsRowView(
                        title: L10n.disableModifierKeys,
                        subtitle: L10n.disableModifierKeysSubtitle,
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
                        title: L10n.ignoreRapidKeys,
                        subtitle: L10n.ignoreRapidKeysSubtitle,
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
                    
                    SettingsRowView(
                        title: L10n.autoMute,
                        subtitle: L10n.autoMuteSubtitle,
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

                    SettingsRowView(
                        title: L10n.autoEnableOnHeadphone,
                        subtitle: L10n.autoEnableOnHeadphoneSubtitle,
                        control: AnyView(
                            Toggle("", isOn: Binding(
                                get: { SettingsEngine.shared.isAutoEnableOnHeadphoneEnabled() },
                                set: { SettingsEngine.shared.setAutoEnableOnHeadphone($0) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                        ),
                        isLast: true
                    )
                }
                
                SettingsSectionView(title: L10n.soundpacks) {
                    VStack(spacing: 0) {
                        HStack(alignment: .center) {
                            Text(L10n.customSoundpackDir)
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                CustomSoundpackHelper.openCustomSoundpackDirectory()
                            }) {
                                HStack(spacing: 4) {
                                    Text(L10n.open)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                    
                                    Image(systemName: "arrow.up.forward")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
                
                SettingsSectionView(title: L10n.performance) {
                    SettingsRowView(
                        title: L10n.audioLatency,
                        subtitle: L10n.audioLatencySubtitle,
                        control: AnyView(
                            Picker("", selection: $audioBufferSize) {
                                Text(L10n.ultraLow).tag(UInt32(64))
                                Text(L10n.low).tag(UInt32(128))
                                Text(L10n.normal).tag(UInt32(256))
                                Text(L10n.high).tag(UInt32(512))
                                Text(L10n.veryHigh).tag(UInt32(1024))
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
                        title: L10n.reduceCPU,
                        subtitle: L10n.reduceCPUSubtitle,
                        control: AnyView(
                            Picker("", selection: $idleTimeoutSeconds) {
                                Text(L10n.seconds5).tag(5.0)
                                Text(L10n.seconds10).tag(10.0)
                                Text(L10n.seconds30).tag(30.0)
                                Text(L10n.minute1).tag(60.0)
                                Text(L10n.minutes5).tag(300.0)
                                Text(L10n.never).tag(0.0)
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
        .id(refreshID)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadAvailableDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: .volumeDidChange)) { _ in
            volume = Double(SettingsEngine.shared.getVolume())
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioDeviceListDidChange)) { _ in
            loadAvailableDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: .audioDeviceDidChange)) { _ in
            selectedDeviceUID = SettingsEngine.shared.getSelectedAudioDeviceUID() ?? "system-default"
        }
        .onReceive(NotificationCenter.default.publisher(for: .settingsDidChange)) { _ in
            disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
            ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
            autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
            idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
            audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mouseSoundDidChange)) { _ in
            mouseSoundEnabled = SettingsEngine.shared.isMouseSoundEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
    
    private func loadAvailableDevices() {
        var devices = AudioDeviceManager.shared.getAvailableOutputDevices()
            .filter { $0.id != "system-default" }
        
        if let selectedUID = SettingsEngine.shared.getSelectedAudioDeviceUID(),
           selectedUID != "system-default",
           !devices.contains(where: { $0.id == selectedUID }) {
            // Add disconnected device to the list
            let disconnectedDevice = AudioDeviceManager.AudioDevice(
                id: selectedUID,
                name: L10n.unknownDevice,
                deviceID: 0
            )
            devices.insert(disconnectedDevice, at: 0)
        }
        
        availableDevices = devices
    }
}

#Preview("Settings/Sound") {
    SoundSettingsView()
        .frame(width: 500, height: 600)
}

