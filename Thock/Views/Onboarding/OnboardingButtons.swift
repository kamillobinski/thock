import SwiftUI

@available(macOS 14.0, *)
struct OnboardingButton: View {
    enum Kind {
        case primary, secondary
    }

    let title: String
    var kind: Kind = .primary
    let action: () -> Void

    init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    var body: some View {
        styled
            .controlSize(.large)
    }

    @ViewBuilder
    private var styled: some View {
        if #available(macOS 26, *) {
            switch kind {
            case .primary:
                Button(action: action) { Text(title).foregroundStyle(.white) }
                    .buttonStyle(.glassProminent)
            case .secondary:
                Button(title, action: action).buttonStyle(.glass)
            }
        } else {
            switch kind {
            case .primary: Button(title, action: action).buttonStyle(.borderedProminent)
            case .secondary: Button(title, action: action).buttonStyle(.bordered)
            }
        }
    }
}
