import SwiftUI

@available(macOS 14.0, *)
struct KeyChip: View {
    enum Size {
        case regular, small
    }

    let label: String
    var size: Size = .regular
    var pressed = false

    @Environment(\.colorScheme) private var colorScheme

    init(_ label: String, size: Size = .regular, pressed: Bool = false) {
        self.label = label
        self.size = size
        self.pressed = pressed
    }

    static func label(forKeyCode keyCode: Int64, characters: String? = nil) -> String {
        OnboardingKeyboardModel.legend(for: keyCode, characters: characters)
    }

    private var isWord: Bool {
        label.count > 1 && label.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) }
    }

    private var isLight: Bool { colorScheme == .light }

    var body: some View {
        let regular = size == .regular
        let height: CGFloat = regular ? 26 : 18
        let radius: CGFloat = regular ? 6 : 4.5
        let fontSize: CGFloat = regular ? (isWord ? 11 : 13) : (isWord ? 9 : 11)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Text(label)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, regular ? 7 : 5)
            .frame(minWidth: label == "space" ? (regular ? 56 : 40) : height, minHeight: height, maxHeight: height)
            .background {
                shape.fill(fill)
                    .overlay(shape.strokeBorder(border, lineWidth: 1))
                    .shadow(color: .black.opacity(isLight ? 0.10 : 0.30), radius: pressed ? 2.5 : 5, y: pressed ? 0.5 : 1.5)
            }
            .offset(y: pressed ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .accessibilityLabel(label)
    }

    private var fill: Color {
        isLight ? Color.white.opacity(0.85) : Color.black.opacity(0.6)
    }

    private var border: Color {
        isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
    }

    private var textColor: Color {
        isLight ? Color.black.opacity(0.85) : Color.white.opacity(0.9)
    }
}
