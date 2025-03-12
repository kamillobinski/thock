//
//  ToggleMenuItemView.swift
//  Thock
//
//  Created by Kamil Łobiński on 10/03/2025.
//

import SwiftUI

class ToggleMenuItemView: NSView {
    private let toggleSwitch = NSSwitch()
    private let label = NSTextField(labelWithString: "")
    var toggleAction: ((Bool) -> Void)?
    
    init(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 24))
        self.toggleAction = action
        setupUI(title: title, isOn: isOn)
    }
    
    private func setupUI(title: String, isOn: Bool) {
        // Configure Label
        label.stringValue = title
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure Toggle
        toggleSwitch.state = isOn ? .on : .off
        toggleSwitch.target = self
        toggleSwitch.action = #selector(switchToggled)
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Views
        addSubview(label)
        addSubview(toggleSwitch)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleSwitch.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggleSwitch.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    @objc private func switchToggled() {
        toggleAction?(toggleSwitch.state == .on)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
