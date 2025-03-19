//
//  VolumeSliderMenuItem.swift
//  Thock
//
//  Created by Kamil Łobiński on 13/03/2025.
//

import SwiftUI
import AppKit

struct VolumeSliderMenuItem: NSViewRepresentable {
    @Binding var volume: Double
    let onVolumeChange: (Double) -> Void
    let step: Double
    
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: volume, minValue: 0, maxValue: 1, target: context.coordinator, action: #selector(Coordinator.valueChanged(_:)))
        slider.isContinuous = false
        slider.controlSize = .small
        slider.frame = NSRect(x: 0, y: 0, width: 120, height: 20)
        return slider
    }
    
    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = volume
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VolumeSliderMenuItem
        
        init(_ parent: VolumeSliderMenuItem) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            let newValue = round(sender.doubleValue / parent.step) * parent.step
            parent.volume = newValue
            parent.onVolumeChange(newValue)
        }
    }
}
