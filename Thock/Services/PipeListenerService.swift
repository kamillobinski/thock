import Foundation

final class PipeListenerService {
    static let shared = PipeListenerService()
    
    private let pipePath: String
    
    private init() {
        let supportDir = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/thock")
        if !FileManager.default.fileExists(atPath: supportDir.path) {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
        
        self.pipePath = supportDir.appendingPathComponent("thock.pipe").path
        recreatePipeIfNeeded()
        startListening()
    }
    
    func cleanUp() {
        try? FileManager.default.removeItem(atPath: pipePath)
        print("[PIPE] Pipe cleaned up")
    }
    
    private func recreatePipeIfNeeded() {
        var statInfo = stat()
        if stat(pipePath, &statInfo) == 0 {
            // File exists – check if it's actually a pipe
            if (statInfo.st_mode & S_IFMT) != S_IFIFO {
                print("[PIPE] Existing file is not a pipe. Removing.")
                try? FileManager.default.removeItem(atPath: pipePath)
            }
        }
        
        if !FileManager.default.fileExists(atPath: pipePath) {
            let result = pipePath.withCString { mkfifo($0, 0o600) }
            if result != 0 {
                let err = String(cString: strerror(errno))
                print("[PIPE] Failed to create pipe: \(err)")
            } else {
                print("[PIPE] Pipe created at \(pipePath)")
            }
        }
    }
    
    private func startListening() {
        DispatchQueue.global(qos: .background).async { [pipePath] in
            print("[PIPE] Listener started at \(pipePath)")
            
            while true {
                let fd = open(pipePath, O_RDONLY)
                if fd == -1 {
                    let err = String(cString: strerror(errno))
                    print("[PIPE] Failed to open pipe: \(err)")
                    sleep(1)
                    continue
                }
                
                let fileHandle = FileHandle(fileDescriptor: fd)
                let data = fileHandle.readDataToEndOfFile()
                fileHandle.closeFile()
                
                if !data.isEmpty,
                   let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    print("[COMMAND] Received: \(command)")
                    self.handle(command: command)
                }
                
                // Loop continues, reopens pipe
            }
        }
    }
    
    private func handle(command: String) {
        let pattern = #"(".*?"|\S+)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let nsrange = NSRange(command.startIndex..., in: command)
        
        let matches = regex.matches(in: command, range: nsrange)
        let components = matches.compactMap {
            Range($0.range, in: command).map { range in
                var token = String(command[range])
                if token.hasPrefix("\"") && token.hasSuffix("\"") {
                    token = String(token.dropFirst().dropLast())
                }
                return token
            }
        }
        
        guard let commandName = components.first else {
            print("[COMMAND] Empty command")
            return
        }
        
        switch commandName {
        case "set-soundpack":
            handleSetSoundpackCommand(components: components)
        case "set-enabled":
            handleSetEnabledCommand(components: components)
        default:
            print("[COMMAND] Unknown command '\(commandName)'")
        }
    }
    
    private func handleSetSoundpackCommand(components: [String]) {
        guard components.count >= 2 else {
            print("[COMMAND] Invalid set-soundpack format. Usage: set-soundpack <id>")
            return
        }
        
        let idString = components[1]
        
        DispatchQueue.main.async {
            guard let uuid = UUID(uuidString: idString) else {
                print("[COMMAND] Invalid UUID '\(idString)'")
                return
            }
            
            guard let soundpack = SoundpackDatabase().getSoundpack(by: uuid) else {
                print("[COMMAND] Soundpack '\(idString)' not found")
                return
            }
            
            if soundpack.category == "mouse" {
                SoundpackEngine.shared.applyMouse(soundpack: soundpack)
            } else {
                SoundpackEngine.shared.applyKeyboard(soundpack: soundpack)
            }
            print("[COMMAND] Soundpack '\(soundpack.name)' applied successfully")
        }
    }
    
    private func handleSetEnabledCommand(components: [String]) {
        guard components.count == 2 else {
            print("[COMMAND] Invalid set-enabled format. Usage: set-enabled true|false")
            return
        }
        
        let arg = components[1].lowercased()
        let enabled: Bool
        
        switch arg {
        case "true", "1", "yes", "on":
            enabled = true
        case "false", "0", "no", "off":
            enabled = false
        default:
            print("[COMMAND] Invalid value for set-enabled: '\(arg)'")
            return
        }
        
        DispatchQueue.main.async {
            AppEngine.shared.setEnabled(enabled)
            SettingsEngine.shared.refreshMenu()
            print("[COMMAND] Thock is now \(enabled ? "enabled" : "disabled")")
        }
    }
}
