//
//  SoundManager.swift
//  Thock
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import AVFoundation
import CoreAudio
import AudioToolbox

class SoundManager {
    static let shared = SoundManager()
    
    private var engine = AVAudioEngine()
    private var audioPlayers: [String: AVAudioPlayerNode] = [:]
    private var audioBuffers: [String: AVAudioPCMBuffer] = [:]
    
    private let mixer = AVAudioMixerNode()
    private let pitchNode = AVAudioUnitTimePitch()
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        setupAudioEngine()
    }
    
    /// Plays a preloaded sound.
    /// - Parameter name: The name of the file to play.
    func play(sound name: String) {
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
    
    func setGlobalPitch(_ pitch: Float) {
        pitchNode.pitch = pitch
    }
    
    private func setupAudioEngine() {
        mixer.outputVolume = 0.5
        engine.attach(pitchNode)
        engine.attach(mixer)
        
        engine.connect(mixer, to: pitchNode, format: nil)
        engine.connect(pitchNode, to: engine.outputNode, format: nil)
        
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
        engine.detach(pitchNode)
        
        engine.attach(pitchNode)
        engine.attach(mixer)
        
        engine.connect(mixer, to: pitchNode, format: nil)
        engine.connect(pitchNode, to: engine.outputNode, format: nil)
        
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
    /// Supports both bundled and custom user-installed modes.
    /// - Parameter mode: The mode defining which sounds to load.
    func preloadSounds(for mode: Mode) {
        resetAudioNodes()
        
        guard let soundDirectory = resolveSoundDirectory(for: mode) else {
            print("Sound directory not found for mode: \(mode.name)")
            return
        }
        
        do {
            let soundFiles = try FileManager.default.contentsOfDirectory(atPath: soundDirectory.path)
                .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") }
            
            for file in soundFiles {
                let fileURL = soundDirectory.appendingPathComponent(file)
                if let buffer = loadAudioBuffer(from: fileURL) {
                    attachBuffer(fileName: file, buffer: buffer)
                } else {
                    print("Failed to preload buffer: \(file)")
                }
            }
            
            print("Preloaded \(audioBuffers.count) sounds for mode: \(mode.name)")
        } catch {
            print("Error loading sound files: \(error)")
        }
        
        startAudioEngine()
    }
    
    /// Resolves the full path to the sound directory for a given mode.
    /// Distinguishes between bundled modes and custom user-created ones.
    /// - Parameter mode: The mode to resolve directory for.
    /// - Returns: The resolved local file URL if it exists, else `nil`.
    private func resolveSoundDirectory(for mode: Mode) -> URL? {
        let isCustom = mode.path.hasPrefix("CustomSounds/")
        let trimmedPath = mode.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if isCustom {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Thock/\(trimmedPath)", isDirectory: true)
        } else {
            return Bundle.main.resourceURL?
                .appendingPathComponent(trimmedPath, isDirectory: true)
        }
    }
    
    /// Attaches a decoded audio buffer to a new audio player node,
    /// and wires it into the engine pipeline for playback.
    /// - Parameters:
    ///   - fileName: The sound file’s name, used as the lookup key.
    ///   - buffer: The preloaded audio buffer for that file.
    private func attachBuffer(fileName: String, buffer: AVAudioPCMBuffer) {
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: buffer.format)
        
        audioPlayers[fileName] = player
        audioBuffers[fileName] = buffer
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
    
    /// Returns the UID of the current output device (or "default" if not found).
    func getCurrentOutputDeviceUID() -> String {
        var defaultDeviceID = AudioDeviceID(0)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &defaultDeviceID
        )
        guard status == noErr else { return "default" }

        var deviceUID: CFString = "default" as CFString
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let uidStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &uidAddress,
            0,
            nil,
            &uidSize,
            &deviceUID
        )
        if uidStatus == noErr, let swiftUID = deviceUID as String? {
            return swiftUID
        }
        return "default"
    }
}
