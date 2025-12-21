//
//  ThockApp.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import SwiftUI

@main
struct ThockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
