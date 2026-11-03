import SwiftUI
import ApplicationServices

@available(macOS 14.0, *)
@Observable
final class AccessibilityPermissionWatcher {
    private(set) var isGranted = AccessibilityPermissionWatcher.isTrusted()
    private(set) var didOpenSettings = false
    @ObservationIgnored private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let granted = AccessibilityPermissionWatcher.isTrusted()
            if granted != self.isGranted { self.isGranted = granted }
        }
    }

    deinit { timer?.invalidate() }

    static func isTrusted() -> Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "onboardingSimulateNoAccess") { return false }
        #endif
        return AXIsProcessTrusted()
    }

    func requestAccess() {
        didOpenSettings = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

@available(macOS 14.0, *)
struct PermissionStepView: View {
    let watcher: AccessibilityPermissionWatcher
    @State private var audio = OnboardingAudio.shared

    private enum RowState { case done, active, pending }

    var body: some View {
        VStack(spacing: 24) {
            OnboardingTitleBlock(
                title: L10n.onboardingAccessTitle,
                body: L10n.onboardingAccessBody
            )

            VStack(spacing: 0) {
                row(index: 1, title: L10n.onboardingOpenSystemSettings,
                    detail: L10n.onboardingAccessPath,
                    state: watcher.isGranted || watcher.didOpenSettings ? .done : .active)
                Divider().overlay(OnboardingTheme.hairline)
                row(index: 2, title: L10n.onboardingTurnOnThock,
                    detail: L10n.onboardingFlipSwitch,
                    state: watcher.isGranted ? .done : (watcher.didOpenSettings ? .active : .pending))
                Divider().overlay(OnboardingTheme.hairline)
                row(index: 3, title: L10n.onboardingHearEverywhere,
                    detail: nil,
                    state: watcher.isGranted && audio.isSystemTrackingActive ? .done : (watcher.isGranted ? .active : .pending))
            }
            .padding(.horizontal, 14)
            .onboardingPanel(cornerRadius: OnboardingMetrics.panelRadius)
            .animation(OnboardingTheme.motion, value: watcher.isGranted)
            .animation(OnboardingTheme.motion, value: watcher.didOpenSettings)
        }
    }

    private func row(index: Int, title: String, detail: String?, state: RowState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(OnboardingTheme.success)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                case .active:
                    Text("\(index)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(OnboardingTheme.textSecondary, lineWidth: 1))
                case .pending:
                    Text("\(index)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(OnboardingTheme.textTertiary)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(OnboardingTheme.indicatorUpcoming, lineWidth: 1))
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnboardingTheme.rowTitle)
                    .foregroundStyle(state == .pending ? OnboardingTheme.textTertiary : OnboardingTheme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(OnboardingTheme.caption)
                        .foregroundStyle(OnboardingTheme.textTertiary)
                }
            }
            Spacer()
        }
        .frame(height: 56)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(state == .done ? L10n.onboardingStepCompleted : L10n.onboardingStepNotCompleted))
    }
}
