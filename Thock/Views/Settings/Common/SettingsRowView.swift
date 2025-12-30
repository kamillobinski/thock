import SwiftUI

struct SettingsRowView: View {
    let title: String
    let subtitle: String?
    let control: AnyView
    var isLast: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: subtitle == nil ? .center : .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                control
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            
            if !isLast {
                Divider().padding(.horizontal, 10)
            }
        }
    }
}
