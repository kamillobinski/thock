import SwiftUI

/// Center-screen HUD shown in the "Key HUD" display mode: one large cap
/// per currently displayed key, fading in/out with the model visibility.
struct KeyHudView: View {
    @ObservedObject var model: KeyHudModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(model.displayKeys, id: \.self) { keyCode in
                KeyHudCap(label: KeyHudGlyphs.label(for: keyCode), isLight: model.theme == "light")
            }
        }
        .opacity(model.visible ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: model.visible)
        .animation(.easeOut(duration: 0.1), value: model.displayKeys)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct KeyHudCap: View {
    let label: String
    let isLight: Bool

    private var fill: Color {
        isLight ? Color.white.opacity(0.85) : Color.black.opacity(0.6)
    }

    private var border: Color {
        isLight ? Color.black.opacity(0.12) : Color.white.opacity(0.16)
    }

    private var textColor: Color {
        isLight ? Color.black.opacity(0.85) : Color.white.opacity(0.9)
    }

    var body: some View {
        Text(label)
            .font(.system(size: 30, weight: .medium, design: .rounded))
            .foregroundColor(textColor)
            .frame(minWidth: 56, minHeight: 56)
            .padding(.horizontal, 14)
            .background(capBackground)
    }

    private var capBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isLight ? 0.10 : 0.30), radius: 10, y: 3)
    }
}
