import SwiftUI

@available(macOS 14.0, *)
struct KeystrokeStreamView: View {
    @State private var keyboard = OnboardingKeyboardModel.shared
    @State private var audio = OnboardingAudio.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if keyboard.strokes.isEmpty {
                Text(L10n.onboardingStartTyping)
                    .font(.system(size: 13))
                    .foregroundStyle(OnboardingTheme.textTertiary)
                    .transition(.opacity)
            } else {
                stream
            }
        }
        .frame(width: OnboardingTheme.columnWidth, height: 112)
        .overlay(alignment: .bottomTrailing) { caption }
        .animation(.easeOut(duration: 0.15), value: keyboard.strokes)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.onboardingKeystrokes)
    }

    private var stream: some View {
        let strokes = keyboard.strokes
        return HStack(spacing: 6) {
            ForEach(Array(strokes.enumerated()), id: \.element.id) { index, stroke in
                let isNewest = index == strokes.count - 1
                KeyChip(stroke.label, pressed: isNewest && keyboard.isPressed)
                    .opacity(opacity(index: index, count: strokes.count))
                    .transition(insertion)
            }
        }
        .padding(.horizontal, 20)
    }

    private var insertion: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .opacity.combined(with: .offset(x: 6)), removal: .opacity)
    }

    private func opacity(index: Int, count: Int) -> Double {
        guard count > 1 else { return 1 }
        let age = Double(count - 1 - index) / Double(OnboardingKeyboardModel.streamLength - 1)
        return 1 - 0.65 * age
    }

    @ViewBuilder
    private var caption: some View {
        if audio.status == .ready, let name = audio.currentSoundpackId.flatMap({ _ in SoundpackEngine.shared.getCurrentKeyboardSoundpack()?.name }) {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2")
                Text(name)
            }
            .font(OnboardingTheme.caption)
            .foregroundStyle(OnboardingTheme.textTertiary)
            .padding(.trailing, 12)
            .padding(.bottom, 10)
        }
    }
}
