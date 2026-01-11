import SwiftUI

struct SettingsLinkRowView: View {
    let title: String
    let url: String
    let showDivider: Bool

    init(title: String, url: String, showDivider: Bool = true) {
        self.title = title
        self.url = url
        self.showDivider = showDivider
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: {
                    if let url = URL(string: url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(L10n.open)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if showDivider {
                Divider()
                    .padding(.horizontal, 10)
            }
        }
    }
}
