import SwiftUI

@available(macOS 14.0, *)
enum OnboardingTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let panelBorder = Color(nsColor: .separatorColor)
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)
    static let hairline = Color(nsColor: .separatorColor)
    static let success = Color(nsColor: .systemGreen)
    static let chipFill = Color(nsColor: .quaternarySystemFill)
    static let selection = Color(nsColor: .quaternarySystemFill)
    static let indicatorUpcoming = Color(nsColor: .quaternaryLabelColor)

    static let columnWidth: CGFloat = 440
    static var windowCornerRadius: CGFloat = 16
    static let panelRadius: CGFloat = 12

    static func concentricRadius(inset: CGFloat, minimum: CGFloat = 8) -> CGFloat {
        max(windowCornerRadius - inset, minimum)
    }

    static let title = Font.system(size: 26, weight: .semibold)
    static let body = Font.system(size: 14)
    static let rowTitle = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 11)

    static let motion = Animation.easeOut(duration: 0.18)
}

@available(macOS 14.0, *)
struct OnboardingTitleBlock: View {
    let title: String
    let message: String

    init(title: String, body: String) {
        self.title = title
        self.message = body
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(OnboardingTheme.title)
                .tracking(-0.52)
                .foregroundStyle(OnboardingTheme.textPrimary)
            Text(message)
                .font(OnboardingTheme.body)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
    }
}

@available(macOS 14.0, *)
struct OnboardingPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            content
                .background(.fill.quaternary, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(OnboardingTheme.panelBorder, lineWidth: 0.5))
        }
    }
}

@available(macOS 14.0, *)
extension View {
    func onboardingPanel(cornerRadius: CGFloat = OnboardingTheme.panelRadius) -> some View {
        modifier(OnboardingPanelModifier(cornerRadius: cornerRadius))
    }
}

@available(macOS 14.0, *)
struct OnboardingStepIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(width: 16, height: 2)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
        .accessibilityElement()
        .accessibilityLabel(L10n.onboardingStep(current + 1, of: count))
    }

    private func color(for index: Int) -> Color {
        if index == current { return OnboardingTheme.textSecondary }
        return index < current ? OnboardingTheme.textTertiary : OnboardingTheme.indicatorUpcoming
    }
}
