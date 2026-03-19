import SwiftUI

struct SettingsSectionView<Content: View, Trailing: View>: View {
    let title: String
    let trailing: Trailing
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) where Trailing == EmptyView {
        self.title = title
        self.trailing = EmptyView()
        self.content = content()
    }
    
    init(title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                trailing
            }
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
