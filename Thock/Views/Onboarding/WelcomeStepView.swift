import SwiftUI

@available(macOS 14.0, *)
struct WelcomeStepView: View {
    @State private var audio = OnboardingAudio.shared
    @State private var demoPlayed = false
    @State private var isVisible = false

    private static let iconArtRatio: CGFloat = 0.805
    private static let iconSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 20) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable()
                    .frame(width: Self.iconSize / Self.iconArtRatio, height: Self.iconSize / Self.iconArtRatio)
                    .frame(width: Self.iconSize, height: Self.iconSize)
                    .accessibilityHidden(true)

                OnboardingTitleBlock(
                    title: L10n.onboardingWelcomeTitle,
                    body: L10n.onboardingWelcomeBody
                )
            }

            Group {
                if audio.status == .ready {
                    KeystrokeStreamView()
                } else {
                    OnboardingSoundState()
                }
            }
            .frame(height: 112)
            .frame(maxWidth: .infinity)
            .onboardingPanel(cornerRadius: OnboardingMetrics.panelRadius)
        }
        .onAppear {
            isVisible = true
            OnboardingKeyMonitor.shared.acquire()
            playDemoIfReady()
        }
        .onDisappear {
            isVisible = false
            OnboardingKeyboardModel.shared.cancelDemo()
            OnboardingKeyMonitor.shared.release()
        }
        .onChange(of: audio.status) { _, _ in playDemoIfReady() }
    }

    private func playDemoIfReady() {
        guard !demoPlayed, audio.status == .ready, !OnboardingKeyboardModel.shared.hasUserPressed else { return }
        demoPlayed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard isVisible, !OnboardingKeyboardModel.shared.hasUserPressed else { return }
            OnboardingKeyboardModel.shared.type("thock")
        }
    }
}

@available(macOS 14.0, *)
struct OnboardingSoundState: View {
    @State private var audio = OnboardingAudio.shared

    var body: some View {
        Group {
            if audio.status == .unavailable {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(L10n.onboardingCantDownloadSounds)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    OnboardingButton(L10n.onboardingTryAgain, kind: .secondary) { audio.retry() }
                        .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(L10n.onboardingDownloadingFirstSound)
                        .font(OnboardingTheme.body)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                    if let bytes = audio.pendingDownloadBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                            .font(OnboardingTheme.body)
                            .foregroundStyle(OnboardingTheme.textTertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(OnboardingTheme.motion, value: audio.status)
    }
}
