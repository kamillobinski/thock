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
        createPipe()
        startListening()
    }
    
    private func createPipe() {
        if FileManager.default.fileExists(atPath: pipePath) {
            try? FileManager.default.removeItem(atPath: pipePath)
        }
        
        let result = pipePath.withCString { mkfifo($0, 0o600) }
        if result != 0 {
            perror("[PIPE] Failed to create")
        }
    }
    
    private func startListening() {
        DispatchQueue.global(qos: .background).async { [pipePath] in
            print("[PIPE] Listener started at \(pipePath)")
            
            while true {
                let fd = open(pipePath, O_RDONLY)
                if fd == -1 {
                    print("[PIPE] Failed to open \(pipePath)")
                    sleep(1)
                    continue
                }
                
                let fileHandle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
                let data = fileHandle.readDataToEndOfFile()
                
                if !data.isEmpty,
                   let command = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    print("[COMMAND] Received \(command)")
                    self.handle(command: command)
                }
                
                fileHandle.closeFile()
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
            case "-brand":
                brand = value
                index += 2
            case "-author":
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
                print("[COMMAND] Mode \(modeName) not found for author \(author) and brand \(brand)")
                return
            }
            
            ModeEngine.shared.apply(mode: mode)
        }
    }
    
    func cleanUp() {
        try? FileManager.default.removeItem(atPath: pipePath)
    }
}
