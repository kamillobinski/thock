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
    let minimumValue: Double
    let maximumValue: Double
    
    init(pitchVariation: Double, onPitchChange: @escaping (Double) -> Void, step: Double, minimumValue: Double, maximumValue: Double) {
        self._localPitchVariation = State(initialValue: pitchVariation)
        self.onPitchChange = onPitchChange
        self.step = step
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
    }
    
    var body: some View {
        VStack {
            Text(localPitchVariation == 0 ? "Baseline" : "±\(Int(localPitchVariation)) cents")
                .font(.callout)
            Slider(
                value: $localPitchVariation,
                in: Double(minimumValue)...Double(maximumValue),
                step: step,
                onEditingChanged: { _ in
                    onPitchChange(localPitchVariation)
                }
            ).controlSize(.mini)
        }
        .padding()
        .onChange(of: localPitchVariation) { newValue in
            onPitchChange(newValue)
        }
    }
}
