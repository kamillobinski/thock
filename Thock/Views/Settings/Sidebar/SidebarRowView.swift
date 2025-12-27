import SwiftUI

struct SidebarRowView: View {
    let tab: SettingsTab
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.primary.opacity(0.15) : Color.gray.opacity(0.3))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                )
            
            Text(tab.rawValue)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
