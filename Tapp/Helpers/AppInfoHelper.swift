//
//  AppInfoHelper.swift
//  Tapp
//
//  Created by Kamil Łobiński on 08/03/2025.
//

import Foundation

class AppInfoHelper {
    static var appName: String {
        return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown"
    }
    
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
