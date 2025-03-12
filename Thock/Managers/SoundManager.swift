//
//  SoundManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var engine = AVAudioEngine()
    private var audioPlayers: [String: AVAudioPlayerNode] = [:]
    private var audioBuffers: [String: AVAudioPCMBuffer] = [:]
    private let mixer = AVAudioMixerNode()
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)
        do {
            try engine.start()
        } catch {
            print("Error starting AVAudioEngine: \(error)")
        }
    }
    
    func preloadSounds(for mode: Mode) {
        engine.stop()
        for player in audioPlayers.values {
            engine.detach(player)
        }
        audioBuffers.removeAll()
        audioPlayers.removeAll()
        
        do {
            try engine.start()
        } catch {
            print("Error restarting AVAudioEngine: \(error)")
        }
        
        let fileManager = FileManager.default
        guard let soundDirectory = Bundle.main.resourceURL?
            .appendingPathComponent(mode.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), isDirectory: true)
        else {
            print("Sound directory not found.")
            return
        }
        
        do {
            let soundFiles = try fileManager.contentsOfDirectory(atPath: soundDirectory.path)
            
            for file in soundFiles where file.hasSuffix(".mp3") || file.hasSuffix(".wav") {
                let fileURL = soundDirectory.appendingPathComponent(file)
                
                if let buffer = loadAudioBuffer(from: fileURL) {
                    audioBuffers[file] = buffer
                    
                    let player = AVAudioPlayerNode()
                    engine.attach(player)
                    engine.connect(player, to: mixer, format: buffer.format)
                    audioPlayers[file] = player
                }
            }
            print("Preloaded \(audioBuffers.count) sounds successfully.")
            
        } catch {
            print("Error loading sound files: \(error)")
        }
    }
    
    func playSound(soundFileName: String) {
        guard let buffer = audioBuffers[soundFileName], let player = audioPlayers[soundFileName] else {
            print("Sound not found: \(soundFileName)")
            return
        }
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        
        if !player.isPlaying {
            player.play()
        }
    }
    
    private func loadAudioBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try file.read(into: buffer)
            return buffer
        } catch {
            print("Error loading audio buffer: \(error)")
            return nil
        }
    }
}
