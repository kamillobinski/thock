//
//  PitchVariationSliderMenuItem.swift
//  Thock
//
//  Created by Alon Budker on 30/03/2025.
//


import SwiftUI

struct PitchVariationSliderMenuItem: View {
    @State private var localPitchVariation: Double
    let onPitchChange: (Double) -> Void
    let step: Double
    
    init(pitchVariation: Double, onPitchChange: @escaping (Double) -> Void, step: Double) {
        self._localPitchVariation = State(initialValue: pitchVariation)
        self.onPitchChange = onPitchChange
        self.step = step
    }
    
    var body: some View {
        VStack {
            Text("±\(Int(localPitchVariation)) cents")
                .font(.caption)
            Slider(
                value: $localPitchVariation,
                in: 0...50,
                step: step,
                onEditingChanged: { _ in
                    onPitchChange(localPitchVariation)
                }
            )
        }
        .padding()
        .onChange(of: localPitchVariation) { newValue in
            onPitchChange(newValue)
        }
    }
}
