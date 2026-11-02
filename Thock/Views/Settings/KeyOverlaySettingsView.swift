import SwiftUI

/// Settings tab for the floating key overlay.
struct KeyOverlaySettingsView: View {
    @State private var enabled = SettingsEngine.shared.isKeyOverlayEnabled()
    @State private var displayMode = SettingsEngine.shared.keyOverlayMode()
    @State private var clickThrough = SettingsEngine.shared.isKeyOverlayClickThroughEnabled()
    @State private var isLight = SettingsEngine.shared.isKeyOverlayLightTheme()
    @State private var scale = SettingsEngine.shared.keyOverlayScale()
    @State private var opacity = SettingsEngine.shared.keyOverlayOpacity()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                SettingsSectionView(title: L10n.keyOverlay) {
                    SettingsRowView(
                        title: L10n.keyOverlayShow,
                        subtitle: L10n.keyOverlayShowSubtitle,
                        control: AnyView(
                            Toggle(L10n.keyOverlayShow, isOn: $enabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: enabled) { newValue in
                                    SettingsEngine.shared.setKeyOverlay(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayDisplayMode,
                        subtitle: L10n.keyOverlayDisplayModeSubtitle,
                        control: AnyView(
                            Picker("", selection: $displayMode) {
                                Text(L10n.keyOverlayModeKeyboard).tag("keyboard")
                                Text(L10n.keyOverlayModeHud).tag("hud")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                            .labelsHidden()
                            .onChange(of: displayMode) { newValue in
                                SettingsEngine.shared.setKeyOverlayMode(newValue)
                            }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayClickThrough,
                        subtitle: L10n.keyOverlayClickThroughSubtitle,
                        control: AnyView(
                            Toggle(L10n.keyOverlayClickThrough, isOn: $clickThrough)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: clickThrough) { newValue in
                                    SettingsEngine.shared.setKeyOverlayClickThrough(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayLightTheme,
                        subtitle: L10n.keyOverlayLightThemeSubtitle,
                        control: AnyView(
                            Toggle(L10n.keyOverlayLightTheme, isOn: $isLight)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: isLight) { newValue in
                                    SettingsEngine.shared.setKeyOverlayLightTheme(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayScale,
                        subtitle: "\(Int(scale * 100))%",
                        control: AnyView(
                            Slider(value: $scale, in: 0.5...2.0, step: 0.25)
                                .frame(width: 160)
                                .onChange(of: scale) { newValue in
                                    SettingsEngine.shared.setKeyOverlayScale(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayOpacity,
                        subtitle: "\(Int(opacity * 100))%",
                        control: AnyView(
                            Slider(value: $opacity, in: 0.2...1.0, step: 0.05)
                                .frame(width: 160)
                                .onChange(of: opacity) { newValue in
                                    SettingsEngine.shared.setKeyOverlayOpacity(newValue)
                                }
                        )
                    )

                    SettingsRowView(
                        title: L10n.keyOverlayPosition,
                        subtitle: L10n.keyOverlayPositionSubtitle,
                        control: AnyView(
                            Button(L10n.keyOverlayResetPosition) {
                                SettingsEngine.shared.resetKeyOverlayPosition()
                            }
                            .controlSize(.small)
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
