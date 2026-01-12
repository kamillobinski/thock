import SwiftUI

struct SidebarRowView: View {
    let tab: SettingsTab
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: tab.icon)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                )

            Text(tab.localizedName)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
