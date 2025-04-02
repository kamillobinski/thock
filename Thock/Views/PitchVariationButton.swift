//
//  PitchVariationButton.swift
//  Thock
//
//  Created by Kamil Łobiński on 02/04/2025.
//

import SwiftUI

struct PitchVariationButton: View {
    let value: Float
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isCoolingDown = false
    
    private var scaleForState: CGFloat {
        if isPressed {
            return 0.93
        } else if isHovered && !isCoolingDown {
            return 1.05
        } else {
            return 1.0
        }
    }
    
    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.6)
        } else if isHovered {
            return Color.accentColor.opacity(0.2)
        } else {
            return .clear
        }
    }
    
    var body: some View {
        Text(value.clean)
            .font(.system(size: 10, weight: .medium))
            .frame(width: 27.2, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .shadow(color: isHovered ? Color.accentColor.opacity(0.2) : .clear, radius: 4)
            .scaleEffect(scaleForState)
            .opacity(isCoolingDown ? 0.4 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: scaleForState)
            .animation(.easeOut(duration: 0.2), value: isCoolingDown)
            .onHover { hovering in
                if !isSelected && !isCoolingDown {
                    isHovered = hovering
                } else {
                    isHovered = false
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in /* nothing to avoid pretrigger */ }
                    .onEnded { _ in
                        guard !isCoolingDown else { return }
                        
                        isPressed = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isPressed = false
                            isCoolingDown = true
                            onSelect()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isCoolingDown = false
                            }
                        }
                    }
            )
            .buttonStyle(PlainButtonStyle())
    }
}

extension Float {
    var clean: String {
        self == floor(self) ? String(Int(self)) : String(format: "%.1f", self)
    }
}
