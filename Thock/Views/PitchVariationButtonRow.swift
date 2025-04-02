//
//  PitchVariationButtonRow.swift
//  Thock
//
//  Created by Kamil Łobiński on 02/04/2025.
//

import SwiftUI

struct PitchVariationButtonRow: View {
    let values: [Float]
    @Binding var selected: Float
    let onSelect: (Float) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(values, id: \.self) { value in
                PitchVariationButton(
                    value: value,
                    isSelected: selected == value,
                    onSelect: {
                        selected = value
                        onSelect(value)
                    }
                )
            }
        }
        .padding(.horizontal, 4)
    }
}
