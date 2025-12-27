import SwiftUI

struct SettingsSectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.leading, 6)
                .padding(.bottom, 6)
                .padding(.top, 20)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                Rectangle().fill(Color.secondary.opacity(0.05))
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
