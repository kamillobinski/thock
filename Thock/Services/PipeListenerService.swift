//
//  PipeListenerService.swift
//  Thock
//
//  Created by Kamil Łobiński on 28/03/2025.
//

//
//  PipeListenerService.swift
//  Thock
//
//  Created by Kamil Łobiński on 28/03/2025.
//

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
                fileHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty,
                          let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                        return
                    }

                    print("[COMMAND] Received: \(command)")
                    self.handle(command: command)
                }

                // Keep the runloop alive
                RunLoop.current.run()
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
        
        guard components.first == "set-mode", components.count >= 2 else {
            print("[COMMAND] Invalid format")
            return
        }
        
        let modeName = components[1]
        var brand: String?
        var author: String?
        
        var index = 2
        while index < components.count {
            let key = components[index]
            let value = index + 1 < components.count ? components[index + 1] : nil
            
            switch key {
            case "--brand":
                brand = value
                index += 2
            case "--author":
                author = value
                index += 2
            default:
                print("[COMMAND] Unknown flag \(key)")
                index += 1
            }
        }
        
        DispatchQueue.main.async {
            guard let brand = brand, let author = author else {
                print("[COMMAND] Missing brand or author")
                return
            }
            
            let mode = ModeDatabase().getMode(byName: modeName, authorName: author, brandName: brand)
            
            guard let mode = mode else {
                print("[COMMAND] Mode '\(modeName)' not found for author '\(author)' and brand '\(brand)'")
                return
            }
            
            ModeEngine.shared.apply(mode: mode)
            print("[COMMAND] Mode '\(modeName)' applied successfully")
        }
    }
    
    func cleanUp() {
        try? FileManager.default.removeItem(atPath: pipePath)
        print("[PIPE] Pipe cleaned up")
    }
}
