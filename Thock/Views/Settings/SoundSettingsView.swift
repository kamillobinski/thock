import SwiftUI

struct SoundSettingsView: View {
    @State private var volume = Double(SettingsEngine.shared.getVolume())
    @State private var keyboardVolume = Double(SettingsEngine.shared.getKeyboardVolume())
    @State private var mouseVolume = Double(SettingsEngine.shared.getMouseVolume())
    @State private var disableModifierKeys = SettingsEngine.shared.isModifierKeySoundDisabled()
    @State private var ignoreRapidKeyEvents = SettingsEngine.shared.isIgnoreRapidKeyEventsEnabled()
    @State private var autoMuteOnMusicPlayback = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
    @State private var autoMuteOnMicrophoneUse = SettingsEngine.shared.isAutoMuteOnMicrophoneUseEnabled()
    @State private var idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
    @State private var audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
    @State private var availableDevices: [AudioDeviceManager.AudioDevice] = []
    @State private var selectedDeviceUID: String = SettingsEngine.shared.getSelectedAudioDeviceUID() ?? "system-default"
    @State private var mouseSoundEnabled = SettingsEngine.shared.isMouseSoundEnabled()
    @State private var softClippingEnabled = SettingsEngine.shared.isSoftClippingEnabled()
    @State private var spatialAudioEnabled = SettingsEngine.shared.isSpatialAudioEnabled()
    @State private var spatialWidth = Double(SettingsEngine.shared.getSpatialWidth())
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: L10n.output) {
                    volumeRow(title: L10n.master, value: $volume) {
                        SettingsEngine.shared.setVolume(Float($0))
                    }
                    volumeRow(title: L10n.keyboard, value: $keyboardVolume) {
                        SettingsEngine.shared.setKeyboardVolume(Float($0))
                    }
                    volumeRow(title: L10n.mouse, value: $mouseVolume) {
                        SettingsEngine.shared.setMouseVolume(Float($0))
                    }
                    
                    SettingsRowView(
                        title: L10n.playThrough,
                        subtitle: nil,
                        control: AnyView(
                            Picker(L10n.playThrough, selection: $selectedDeviceUID) {
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
                                .labelsHidden()
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
                            Toggle(L10n.mouseClickSound, isOn: $mouseSoundEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: mouseSoundEnabled) { newValue in
                                    SettingsEngine.shared.setMouseSoundEnabled(newValue)
                                }
                        )
                    )
                    
                    SettingsRowView(
                        title: L10n.spatialAudio,
                        subtitle: L10n.spatialAudioSubtitle,
                        control: AnyView(
                            Toggle("", isOn: $spatialAudioEnabled.animation(.easeInOut(duration: 0.2)))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: spatialAudioEnabled) { newValue in
                                    SettingsEngine.shared.setSpatialAudioEnabled(newValue)
                                }
                        )
                    )
                    
                    if spatialAudioEnabled {
                        SettingsRowView(
                            title: L10n.spatialWidth,
                            subtitle: L10n.spatialWidthSubtitle,
                            control: AnyView(
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.and.line.vertical.and.arrow.left")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    Slider(
                                        value: $spatialWidth,
                                        in: Double(SpatialMath.widthRange.lowerBound)...Double(SpatialMath.widthRange.upperBound),
                                        step: 5
                                    )
                                        .frame(width: 140)
                                        .onChange(of: spatialWidth) { newValue in
                                            SettingsEngine.shared.setSpatialWidth(Float(newValue))
                                        }
                                    
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    SettingsRowView(
                        title: L10n.softenLoudPeaks,
                        subtitle: L10n.softenLoudPeaksSubtitle,
                        control: AnyView(
                            Toggle(L10n.softenLoudPeaks, isOn: $softClippingEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .accessibilityHint(Text(L10n.softenLoudPeaksSubtitle))
                                .onChange(of: softClippingEnabled) { newValue in
                                    SettingsEngine.shared.setSoftClippingEnabled(newValue)
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
                            Toggle(L10n.disableModifierKeys, isOn: $disableModifierKeys)
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
                            Toggle(L10n.ignoreRapidKeys, isOn: $ignoreRapidKeyEvents)
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
                            Toggle(L10n.autoMute, isOn: $autoMuteOnMusicPlayback)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: autoMuteOnMusicPlayback) { newValue in
                                    SettingsEngine.shared.setAutoMuteOnMusicPlayback(newValue)
                                }
                        )
                    )
                    
                    SettingsRowView(
                        title: L10n.autoMuteOnMicrophoneUse,
                        subtitle: L10n.autoMuteOnMicrophoneUseSubtitle,
                        control: AnyView(
                            Toggle("", isOn: $autoMuteOnMicrophoneUse)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: autoMuteOnMicrophoneUse) { newValue in
                                    SettingsEngine.shared.setAutoMuteOnMicrophoneUse(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.autoEnableOnHeadphone,
                        subtitle: L10n.autoEnableOnHeadphoneSubtitle,
                        control: AnyView(
                            Toggle(L10n.autoEnableOnHeadphone, isOn: Binding(
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
                
                SettingsSectionView(title: L10n.performance) {
                    SettingsRowView(
                        title: L10n.audioLatency,
                        subtitle: L10n.audioLatencySubtitle,
                        control: AnyView(
                            Picker(L10n.audioLatency, selection: $audioBufferSize) {
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
                            Picker(L10n.reduceCPU, selection: $idleTimeoutSeconds) {
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
            keyboardVolume = Double(SettingsEngine.shared.getKeyboardVolume())
            mouseVolume = Double(SettingsEngine.shared.getMouseVolume())
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
            autoMuteOnMicrophoneUse = SettingsEngine.shared.isAutoMuteOnMicrophoneUseEnabled()
            idleTimeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
            audioBufferSize = SettingsEngine.shared.getAudioBufferSize()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mouseSoundDidChange)) { _ in
            mouseSoundEnabled = SettingsEngine.shared.isMouseSoundEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .softClippingDidChange)) { _ in
            softClippingEnabled = SettingsEngine.shared.isSoftClippingEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            refreshID = UUID()
        }
    }
    
    private func volumeRow(title: String, value: Binding<Double>, onChange: @escaping (Double) -> Void) -> some View {
        SettingsRowView(
            title: title,
            subtitle: nil,
            control: AnyView(
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)

                    Slider(value: value, in: 0...1)
                        .frame(width: 240)
                        .accessibilityLabel(Text(title))
                        .accessibilityValue(Text(value.wrappedValue.formatted(.percent.precision(.fractionLength(0)))))
                        .onChange(of: value.wrappedValue, perform: onChange)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            )
        )
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

