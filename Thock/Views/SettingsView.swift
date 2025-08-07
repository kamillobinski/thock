import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var showSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.title2.bold())
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Global Keyboard Shortcut")
                    .font(.headline)
                
                HStack {
                    Text("Toggle Thock on/off:")
                    KeyboardShortcuts.Recorder("toggleThock", name: .toggleThock)
                }
                
                Text("Press this shortcut anywhere to quickly enable or disable Thock.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Close") {
                    if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first(where: { $0.contentView is NSHostingView<SettingsWindow> }) {
                        window.close()
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

struct SettingsWindow: View {
    var body: some View {
        SettingsView()
    }
}
