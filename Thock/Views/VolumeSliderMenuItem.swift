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
        context.coordinator.slider = slider
        context.coordinator.updateValue()
        return slider
    }
    
    func updateNSView(_ nsView: NSSlider, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateValue()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VolumeSliderMenuItem
        weak var slider: NSSlider?
        private var volumeObserver: NSObjectProtocol?
        
        init(_ parent: VolumeSliderMenuItem) {
            self.parent = parent
            super.init()
            volumeObserver = NotificationCenter.default.addObserver(
                forName: .volumeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateValue()
            }
        }

        deinit {
            if let volumeObserver {
                NotificationCenter.default.removeObserver(volumeObserver)
            }
        }

        func updateValue() {
            slider?.doubleValue = parent.volume
            slider?.setAccessibilityLabel(L10n.volume)
            slider?.setAccessibilityValueDescription(parent.volume.formatted(.percent.precision(.fractionLength(0))))
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            let newValue = round(sender.doubleValue / parent.step) * parent.step
            sender.doubleValue = newValue
            sender.setAccessibilityValueDescription(newValue.formatted(.percent.precision(.fractionLength(0))))
            parent.volume = newValue
            parent.onVolumeChange(newValue)
        }
    }
}
