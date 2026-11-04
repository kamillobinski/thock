import SwiftUI

@available(macOS 14.0, *)
struct PermissionRecoveryView: View {
    let onClose: () -> Void

    @State private var permission = AccessibilityPermissionWatcher()

    static let windowSize = CGSize(width: 560, height: 460)
    private static let iconArtRatio: CGFloat = 0.805
    private static let iconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .frame(width: Self.iconSize / Self.iconArtRatio, height: Self.iconSize / Self.iconArtRatio)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .accessibilityHidden(true)

                PermissionStepView(watcher: permission)
            }
            .frame(width: OnboardingMetrics.columnWidth)
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                Spacer()
                if permission.isGranted {
                    OnboardingButton(L10n.onboardingContinue, kind: .primary, action: onClose)
                        .keyboardShortcut(.defaultAction)
                } else {
                    OnboardingButton(L10n.onboardingSkipForNow, kind: .secondary, action: onClose)
                        .keyboardShortcut(.cancelAction)
                    OnboardingButton(L10n.onboardingOpenSettings, kind: .primary) { permission.requestAccess() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(width: OnboardingMetrics.columnWidth)
            .padding(.bottom, 28)
        }
        .padding(.top, 24)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand(perform: onClose)
    }
}
