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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        mixer.outputVolume = 0.5
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)
        startAudioEngine()
    }
    
    private func startAudioEngine() {
        do {
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            print("Error starting AVAudioEngine: \(error)")
        }
    }
    
    /// Handles output device change.
    @objc private func handleEngineConfigChange(notification: Notification) {
        engine.stop()
        engine.reset()

        // Detach and reattach mixer
        engine.detach(mixer)
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)

        // Reattach all players
        for (fileName, buffer) in audioBuffers {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: buffer.format)
            audioPlayers[fileName] = player
        }

        startAudioEngine()
    }
    
    /// Stops and detaches all existing audio nodes to prevent memory leaks.
    private func resetAudioNodes() {
        for player in audioPlayers.values {
            player.stop()
            engine.detach(player)
        }
        
        audioPlayers.removeAll()
        audioBuffers.removeAll()
    }
    
    /// Preloads sound files from the given mode’s directory.
    /// - Parameter mode: The mode defining which sounds to load.
    func preloadSounds(for mode: Mode) {
        resetAudioNodes()
        
        let fileManager = FileManager.default
        guard let soundDirectory = Bundle.main.resourceURL?
            .appendingPathComponent(mode.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), isDirectory: true)
        else {
            print("Sound directory not found.")
            return
        }
        
        do {
            let soundFiles = try fileManager.contentsOfDirectory(atPath: soundDirectory.path)
                .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") }
            
            for file in soundFiles {
                let fileURL = soundDirectory.appendingPathComponent(file)
                if let buffer = loadAudioBuffer(from: fileURL) {
                    let player = AVAudioPlayerNode()
                    engine.attach(player)
                    engine.connect(player, to: mixer, format: buffer.format)
                    audioPlayers[file] = player
                    audioBuffers[file] = buffer
                }
            }
            print("Preloaded \(audioBuffers.count) sounds successfully.")
        } catch {
            print("Error loading sound files: \(error)")
        }
        startAudioEngine()
    }
    
    /// Loads an audio file into a buffer.
    /// - Parameter url: File URL of the sound.
    /// - Returns: `AVAudioPCMBuffer` if successful, otherwise `nil`.
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
    
    /// Plays sound for a key press event.
    func playSound(for keyCode: Int64, isKeyDown: Bool) {
        guard AppStateManager.shared.isEnabled else { return }
        
        let keyType = KeyMapper.fromKeyCode(keyCode)
        let soundList = isKeyDown
        ? ModeConfigManager.shared.getKeyDownSounds(for: keyType)
        : ModeConfigManager.shared.getKeyUpSounds(for: keyType)
        
        if let soundFileName = soundList.randomElement() {
            SoundManager.shared.playSound(name: soundFileName)
        } else {
            print("Warning: (keydown: \(isKeyDown)) No available sound for keyCode: \(keyCode)")
        }
    }
    
    /// Plays a preloaded sound.
    /// - Parameter name: The name of the file to play.
    func playSound(name: String) {
        guard let buffer = audioBuffers[name], let player = audioPlayers[name] else {
            print("Sound not found: \(name)")
            return
        }
        
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        
        if !player.isPlaying {
            player.play()
        }
    }
    
    func setVolume(_ newValue: Float) {
        mixer.outputVolume = newValue
    }
    
    func getVolume() -> Float {
        return mixer.outputVolume
    }
}
