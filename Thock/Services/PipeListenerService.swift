import Foundation
import OSLog

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
        Logger.cli.debug("Pipe cleaned up")
    }
    
    private func recreatePipeIfNeeded() {
        var statInfo = stat()
        if stat(pipePath, &statInfo) == 0 {
            // File exists – check if it's actually a pipe
            if (statInfo.st_mode & S_IFMT) != S_IFIFO {
                Logger.cli.warning("Existing file is not a pipe, removing it")
                try? FileManager.default.removeItem(atPath: pipePath)
            }
        }
        
        if !FileManager.default.fileExists(atPath: pipePath) {
            let result = pipePath.withCString { mkfifo($0, 0o600) }
            if result != 0 {
                let err = String(cString: strerror(errno))
                Logger.cli.error("Failed to create pipe: \(err, privacy: .public)")
            } else {
                Logger.cli.debug("Pipe created at \(self.pipePath, privacy: .public)")
            }
        }
    }
    
    private func startListening() {
        DispatchQueue.global(qos: .background).async { [pipePath] in
            Logger.cli.debug("Listener started at \(pipePath, privacy: .public)")
            
            while true {
                let fd = open(pipePath, O_RDONLY)
                if fd == -1 {
                    let err = String(cString: strerror(errno))
                    Logger.cli.error("Failed to open pipe: \(err, privacy: .public)")
                    sleep(1)
                    continue
                }
                
                let fileHandle = FileHandle(fileDescriptor: fd)
                let data = fileHandle.readDataToEndOfFile()
                fileHandle.closeFile()
                
                if !data.isEmpty,
                   let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    Logger.cli.debug("Received: \(command, privacy: .public)")
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
            Logger.cli.debug("Empty command")
            return
        }
        
        switch commandName {
        case "set-soundpack":
            handleSetSoundpackCommand(components: components)
        case "set-enabled":
            handleSetEnabledCommand(components: components)
        default:
            Logger.cli.warning("Unknown command '\(commandName, privacy: .public)'")
        }
    }
    
    private func handleSetSoundpackCommand(components: [String]) {
        guard components.count >= 2 else {
            Logger.cli.warning("Invalid set-soundpack format, expected: set-soundpack <id>")
            return
        }
        
        let idString = components[1]
        
        DispatchQueue.main.async {
            guard let uuid = UUID(uuidString: idString) else {
                Logger.cli.warning("Invalid UUID '\(idString, privacy: .public)'")
                return
            }
            
            guard let soundpack = SoundpackDatabase().getSoundpack(by: uuid) else {
                Logger.cli.warning("Soundpack '\(idString, privacy: .public)' not found")
                return
            }
            
            if soundpack.category == "mouse" {
                SoundpackEngine.shared.applyMouse(soundpack: soundpack)
            } else {
                SoundpackEngine.shared.applyKeyboard(soundpack: soundpack)
            }
            Logger.cli.info("Soundpack '\(soundpack.name, privacy: .public)' applied successfully")
        }
    }
    
    private func handleSetEnabledCommand(components: [String]) {
        guard components.count == 2 else {
            Logger.cli.warning("Invalid set-enabled format, expected: set-enabled true|false")
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
            Logger.cli.warning("Invalid value for set-enabled: '\(arg, privacy: .public)'")
            return
        }
        
        DispatchQueue.main.async {
            AppEngine.shared.setEnabled(enabled)
            SettingsEngine.shared.refreshMenu()
            Logger.cli.info("Thock is now \(enabled ? "enabled" : "disabled", privacy: .public)")
        }
    }
}
