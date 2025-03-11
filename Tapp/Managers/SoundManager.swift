//
//  SoundManager.swift
//  Tapp
//
//  Created by Kamil Łobiński on 07/03/2025.
//

import AVFoundation

class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()
    
    private var audioDataCache: [String: Data] = [:]
    private var activeAudioPlayers: [AVAudioPlayer] = []
    
    func playSound(soundFileName: String, mode: Mode) {
        let soundFolder = mode.path
        
        if let cachedData = audioDataCache[soundFileName] {
            createAndPlayAudioPlayer(with: cachedData)
        } else {
            if let soundURL = Bundle.main.url(forResource: soundFileName, withExtension: nil, subdirectory: soundFolder) {
                do {
                    let soundData = try Data(contentsOf: soundURL)
                    audioDataCache[soundFileName] = soundData
                    createAndPlayAudioPlayer(with: soundData)
                } catch {
                    print("Error loading sound data: \(error)")
                }
            } else {
                print("Sound file not found: \(soundFileName) in \(soundFolder)")
            }
        }
    }
    
    private func createAndPlayAudioPlayer(with soundData: Data) {
        do {
            let player = try AVAudioPlayer(data: soundData)
            player.prepareToPlay()
            player.delegate = self
            player.play()
            activeAudioPlayers.append(player)
        } catch {
            print("Error playing sound: \(error)")
        }
    }
    
    func clearAudioDataCache() {
        audioDataCache.removeAll()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activeAudioPlayers.removeAll { $0 == player }
    }
}
