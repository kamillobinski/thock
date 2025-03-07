//
//  TappApp.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import SwiftUI

@main
struct TappApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
