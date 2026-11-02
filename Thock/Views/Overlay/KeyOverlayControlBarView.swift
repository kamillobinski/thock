import SwiftUI

/// Temporary control bar shown above the key overlay (⌃⌥L).
/// While visible, the overlay becomes draggable; it auto-hides after
/// a few seconds of inactivity.
struct KeyOverlayControlBarView: View {
    @State private var scale: Double = SettingsEngine.shared.keyOverlayScale()
    @State private var opacity: Double = SettingsEngine.shared.keyOverlayOpacity()
    @State private var isLight: Bool = SettingsEngine.shared.isKeyOverlayLightTheme()
    @State private var clickThrough: Bool = SettingsEngine.shared.isKeyOverlayClickThroughEnabled()

    var body: some View {
        HStack(spacing: 12) {
            // Theme toggle
            Button(action: {
                interact()
                isLight = SettingsEngine.shared.toggleKeyOverlayTheme()
            }) {
                Image(systemName: isLight ? "sun.max.fill" : "moon.fill")
            }
            .help(L10n.keyOverlayThemeToggle)

            Divider().frame(height: 16)

            // Zoom
            Button(action: {
                SettingsEngine.shared.decreaseKeyOverlayScale()
                scale = SettingsEngine.shared.keyOverlayScale()
                interact()
            }) { Image(systemName: "minus") }
            .help(L10n.keyOverlayZoomOut)

            Text("\(Int(scale * 100))%")
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 40)

            Button(action: {
                SettingsEngine.shared.increaseKeyOverlayScale()
                scale = SettingsEngine.shared.keyOverlayScale()
                interact()
            }) { Image(systemName: "plus") }
            .help(L10n.keyOverlayZoomIn)

            Divider().frame(height: 16)

            // Opacity slider
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 11))
            Slider(value: $opacity, in: 0.2...1.0, step: 0.05)
                .frame(width: 90)
                .onChange(of: opacity) { newValue in
                    SettingsEngine.shared.setKeyOverlayOpacity(newValue)
                    interact()
                }

            Divider().frame(height: 16)

            // Click-through toggle
            Button(action: {
                interact()
                clickThrough = SettingsEngine.shared.toggleKeyOverlayClickThrough()
            }) {
                Image(systemName: clickThrough ? "cursorarrow.rays" : "cursorarrow")
            }
            .help(clickThrough ? L10n.keyOverlayClickThroughOnHint : L10n.keyOverlayClickThroughOffHint)

            // Reset position
            Button(action: {
                SettingsEngine.shared.resetKeyOverlayPosition()
                interact()
            }) {
                Image(systemName: "arrow.down.to.line")
            }
            .help(L10n.keyOverlayResetPosition)

            Divider().frame(height: 16)

            // Done
            Button(L10n.keyOverlayDone) {
                KeyOverlayManager.shared.hideControlBar()
            }
            .controlSize(.small)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func interact() {
        KeyOverlayManager.shared.noteControlBarInteraction()
    }
}
