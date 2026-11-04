import SwiftUI
import KeyboardShortcuts

@available(macOS 14.0, *)
struct DoneStepView: View {
    @State private var openAtLogin = SettingsEngine.shared.isOpenAtLoginEnabled()
    @State private var toggleShortcut = KeyboardShortcuts.getShortcut(for: .toggleThock)
    @State private var recordingShortcut = false

    var body: some View {
        VStack(spacing: 24) {
            OnboardingTitleBlock(
                title: L10n.onboardingDoneTitle,
                body: L10n.onboardingDoneBody
            )

            VStack(spacing: 0) {
                row(L10n.onboardingOpenThock) {
                    HStack(spacing: 6) {
                        ThockMark()
                            .fill(OnboardingTheme.textSecondary)
                            .frame(width: 12 * ThockMark.aspect, height: 12)
                        mouseAction(L10n.onboardingClick)
                    }
                }
                divider
                row(L10n.onboardingMuteOrUnmute) { mouseAction(L10n.onboardingRightClick) }
                divider
                row(L10n.toggleThock) {
                    if let toggleShortcut, !recordingShortcut {
                        Text(toggleShortcut.description)
                            .font(OnboardingTheme.rowTitle.monospacedDigit())
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    } else if recordingShortcut {
                        KeyboardShortcuts.Recorder(for: .toggleThock) { shortcut in
                            toggleShortcut = shortcut
                            if shortcut != nil { recordingShortcut = false }
                        }
                        .controlSize(.small)
                    } else {
                        Button(L10n.onboardingSetShortcut) { recordingShortcut = true }
                            .buttonStyle(.link)
                            .font(OnboardingTheme.rowTitle)
                    }
                }
                divider
                HStack {
                    Text(L10n.launchAtLogin)
                        .font(OnboardingTheme.rowTitle)
                        .foregroundStyle(OnboardingTheme.textPrimary)
                    Spacer()
                    Toggle(L10n.launchAtLogin, isOn: $openAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: openAtLogin) { _, value in SettingsEngine.shared.setOpenAtLogin(value) }
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 14)
            .onboardingPanel(cornerRadius: OnboardingMetrics.panelRadius)
        }
        .onAppear { OnboardingWindowController.shared.highlightStatusItem() }
    }

    private var divider: some View {
        Divider().overlay(OnboardingTheme.hairline)
    }

    private func row<Accessory: View>(_ title: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(OnboardingTheme.rowTitle)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Spacer()
            accessory()
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
    }

    private func mouseAction(_ text: String) -> some View {
        Text(text)
            .font(OnboardingTheme.rowTitle)
            .foregroundStyle(OnboardingTheme.textTertiary)
    }

}
