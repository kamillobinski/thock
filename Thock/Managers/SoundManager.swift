import Foundation
import AudioToolbox
import AVFoundation
import CoreAudio
import OSLog
import Accelerate

final class SoundManager {
    static let shared = SoundManager()
    
    // MARK: - Constants
    private static let defaultDeviceUID = "default"
    
    // MARK: - State
    private(set) var isReady = false
    
    // MARK: - Audio Queue State
    private var audioQueue: AudioQueueRef?
    private let numberOfBuffers = 3
    private var audioBuffers: [AudioQueueBufferRef] = []
    private var isQueueRunning = false
    private var idleTimeoutTimer: DispatchSourceTimer?
    private let timerLock = NSLock()
    
    // MARK: - Audio Format
    private var sampleRate: Float64 = 44100.0
    private let channelCount: UInt32 = 2
    private let bitsPerChannel: UInt32 = 32
    private var framesPerBuffer: UInt32
    private var currentBufferSize: UInt32 = SettingsManager.shared.audioBufferSize
    
    private var audioFormat = AudioStreamBasicDescription()
    
    // MARK: - Sound Storage
    private var soundLibrary: [String: PCMSound] = [:]
    private var activeSounds: [ActiveSound] = []
    private let activeSoundsLock = NSLock()
    
    // MARK: - Idle State Tracking
    private var idleCallbackCount: Int = 0
    
    // MARK: - Volume Control
    private var volume: Float = 0.5
    private let volumeLock = NSLock()
    
    // MARK: - Models
    private struct PCMSound {
        let data: [Float]
        let frameCount: Int
    }
    
    private class ActiveSound {
        let pcmData: [Float]
        let frameCount: Int
        var currentFrame: Int = 0
        let latencyId: UUID?
        var hasReportedPlayback: Bool = false
        let pitchOffset: Float
        
        init(pcmData: [Float], frameCount: Int, latencyId: UUID?, pitchOffset: Float) {
            self.pcmData = pcmData
            self.frameCount = frameCount
            self.latencyId = latencyId
            self.pitchOffset = pitchOffset
        }
        
        var isFinished: Bool {
            currentFrame >= frameCount
        }
    }
    
    // MARK: - Initialization
    private init() {
        framesPerBuffer = currentBufferSize
        detectHardwareSampleRate()
        setupAudioFormat()
        configureLowLatencyAudio()
        createAudioQueue()
        
        // Listen for settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: .settingsDidChange,
            object: nil
        )
    }
    
    @objc private func handleSettingsChange() {
        let newBufferSize = SettingsManager.shared.audioBufferSize
        
        // Handle buffer size change
        if newBufferSize != currentBufferSize {
            reinitializeAudioQueue(with: newBufferSize)
            return
        }
        
        // Reset idle timer with new timeout value
        if isQueueRunning {
            resetIdleTimer()
        }
    }
    
    private func reinitializeAudioQueue(with newBufferSize: UInt32) {
        // Cancel idle timer
        timerLock.lock()
        let oldTimer = idleTimeoutTimer
        idleTimeoutTimer = nil
        timerLock.unlock()
        oldTimer?.cancel()
        
        // Stop and dispose current audio queue
        if let queue = audioQueue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
        
        // update state
        activeSoundsLock.lock()
        currentBufferSize = newBufferSize
        framesPerBuffer = newBufferSize
        audioQueue = nil
        audioBuffers = []
        isQueueRunning = false
        activeSounds = []
        activeSoundsLock.unlock()
        
        // Reinitialize audio queue
        setupAudioFormat()
        configureLowLatencyAudio()
        createAudioQueue()
        
        Logger.audio.info("Audio queue reinitialized with buffer size: \(newBufferSize) frames")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        idleTimeoutTimer?.cancel()
        if let queue = audioQueue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
    }
    
    // MARK: - Idle Timeout Management
    
    private func setupIdleTimeoutTimer() {
        let timeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
        
        // 0 means nevaa
        guard timeoutSeconds > 0 else {
            idleTimeoutTimer = nil
            return
        }
        
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + timeoutSeconds, repeating: .never)
        timer.setEventHandler { [weak self] in
            self?.stopQueueIfIdle()
        }
        timer.resume()
        idleTimeoutTimer = timer
    }
    
    private func resetIdleTimer() {
        timerLock.lock()
        
        let oldTimer = idleTimeoutTimer
        idleTimeoutTimer = nil
        timerLock.unlock()
        
        oldTimer?.cancel()
        
        timerLock.lock()
        setupIdleTimeoutTimer()
        timerLock.unlock()
    }
    
    private func stopQueueIfIdle() {
        activeSoundsLock.lock()
        let shouldStop = activeSounds.isEmpty && isQueueRunning
        activeSoundsLock.unlock()
        
        guard shouldStop, let queue = audioQueue else { return }
        
        let status = AudioQueueStop(queue, false)
        if status == noErr {
            isQueueRunning = false
            let timeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
            Logger.audio.info("Audio queue stopped after \(timeoutSeconds)s idle")
        } else {
            Logger.audio.error("Failed to stop audio queue: \(status)")
        }
    }
    
    private func restartQueue() {
        guard !isQueueRunning, let queue = audioQueue else { return }
        
        let status = AudioQueueStart(queue, nil)
        if status == noErr {
            isQueueRunning = true
            resetIdleTimer()
            Logger.audio.info("Audio queue restarted")
        } else {
            Logger.audio.error("Failed to restart audio queue: \(status)")
        }
    }
    
    // MARK: - Audio Format Setup
    private func detectHardwareSampleRate() {
        guard let defaultDeviceID = getDefaultOutputDeviceID() else {
            Logger.audio.warning("Default output device unavailable, using 44.1kHz fallback")
            return
        }
        
        // Query nominal sample rate
        var nominalSampleRate: Float64 = 44100.0
        var sampleRateAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var sampleRateSize = UInt32(MemoryLayout<Float64>.size)
        
        let sampleRateStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &sampleRateAddress,
            0,
            nil,
            &sampleRateSize,
            &nominalSampleRate
        )
        
        if sampleRateStatus == noErr {
            sampleRate = nominalSampleRate
            Logger.audio.info("Hardware sample rate detected: \(String(format: "%.1f Hz", self.sampleRate))")
        } else {
            Logger.audio.warning("Sample rate query failed, using 44.1kHz fallback")
        }
    }
    
    private func setupAudioFormat() {
        audioFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size) * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size) * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: bitsPerChannel,
            mReserved: 0
        )
    }
    
    // MARK: - Low-Latency Configuration
    private func configureLowLatencyAudio() {
        guard let defaultDeviceID = getDefaultOutputDeviceID() else {
            Logger.audio.error("Cannot configure audio: default output device unavailable")
            return
        }
        
        var bufferSize: UInt32 = currentBufferSize
        var bufferAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let bufferStatus = AudioObjectSetPropertyData(
            defaultDeviceID,
            &bufferAddress,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &bufferSize
        )
        
        if bufferStatus == noErr {
            let latencyMs = (Double(currentBufferSize) / sampleRate) * 1000.0
            Logger.audio.info("Hardware buffer configured: \(self.currentBufferSize) frames (~\(String(format: "%.1f", latencyMs))ms)")
        }
        
        measureHardwareLatency(deviceID: defaultDeviceID)
    }
    
    // MARK: - Audio Queue Creation
    private func createAudioQueue() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let status = AudioQueueNewOutput(
            &audioFormat,
            audioQueueCallback,
            selfPointer,
            CFRunLoopGetCurrent(),
            CFRunLoopMode.commonModes.rawValue,
            0,
            &audioQueue
        )
        
        guard status == noErr, let queue = audioQueue else {
            Logger.audio.error("Audio queue creation failed with status: \(status)")
            return
        }
        
        // Allocate buffers
        let bufferSize = framesPerBuffer * audioFormat.mBytesPerFrame
        for _ in 0..<numberOfBuffers {
            var buffer: AudioQueueBufferRef?
            let allocStatus = AudioQueueAllocateBuffer(queue, bufferSize, &buffer)
            if allocStatus == noErr, let buffer = buffer {
                audioBuffers.append(buffer)
                // Prime the buffer
                primeBuffer(buffer, queue: queue)
            } else {
                Logger.audio.error("Buffer allocation failed with status: \(allocStatus)")
            }
        }
        
        // Verify allocated all buffers
        guard audioBuffers.count == numberOfBuffers else {
            Logger.audio.error("Incomplete buffer allocation: \(self.audioBuffers.count)/\(self.numberOfBuffers)")
            return
        }
        
        // Start the queue
        let startStatus = AudioQueueStart(queue, nil)
        guard startStatus == noErr else {
            Logger.audio.error("Audio queue start failed with status: \(startStatus)")
            return
        }
        
        isQueueRunning = true
        isReady = true
        setupIdleTimeoutTimer()
        Logger.audio.info("Audio system initialized successfully")
    }
    
    // MARK: - Audio Callback
    private let audioQueueCallback: AudioQueueOutputCallback = { userData, queue, buffer in
        guard let userData = userData else { return }
        let manager = Unmanaged<SoundManager>.fromOpaque(userData).takeUnretainedValue()
        manager.fillBuffer(buffer, queue: queue)
    }
    
    private func fillBuffer(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        let frameCount = Int(framesPerBuffer)
        
        // Get buffer pointer
        let bufferData = buffer.pointee.mAudioData
        let outputBuffer = bufferData.assumingMemoryBound(to: Float.self)
        
        // Check for active sounds
        activeSoundsLock.lock()
        
        if activeSounds.isEmpty {
            // No active sounds, output silence and return early
            let shouldClear = idleCallbackCount < numberOfBuffers
            idleCallbackCount += 1
            activeSoundsLock.unlock()
            
            if shouldClear {
                memset(outputBuffer, 0, Int(framesPerBuffer * audioFormat.mBytesPerFrame))
            }
            
            buffer.pointee.mAudioDataByteSize = framesPerBuffer * audioFormat.mBytesPerFrame
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
            return
        }
        
        idleCallbackCount = 0
        
        // Zero out buffer
        memset(outputBuffer, 0, Int(framesPerBuffer * audioFormat.mBytesPerFrame))
        
        // Read volume without lock, one-buffer-cycle delay is ookayish
        let currentVolume = volume
        
        for sound in activeSounds {
            // Report playback started on first render
            if ENABLE_LATENCY_MEASUREMENT && !sound.hasReportedPlayback {
                sound.hasReportedPlayback = true
                recordLatencyCheckpoint(sound.latencyId, point: .playbackStarted)
                completeLatencyMeasurement(sound.latencyId)
            }
            
            // EARLY EXIT FOR PITCH
            if sound.pitchOffset == 0.0 {
                let remainingFrames = sound.frameCount - sound.currentFrame
                let framesToCopy = min(frameCount, remainingFrames)
                
                if framesToCopy > 0 {
                    let startSample = sound.currentFrame * Int(channelCount)
                    let sampleCount = framesToCopy * Int(channelCount)
                    
                    sound.pcmData.withUnsafeBufferPointer { pcmBuffer in
                        var volumeScalar = currentVolume
                        vDSP_vsma(
                            pcmBuffer.baseAddress!.advanced(by: startSample), 1,
                            &volumeScalar,
                            outputBuffer, 1,
                            outputBuffer, 1,
                            vDSP_Length(sampleCount)
                        )
                    }
                    
                    sound.currentFrame += framesToCopy
                }
            } else {
                // Pitch variation enabled RESAMPLING TIME
                renderWithPitch(sound: sound, outputBuffer: outputBuffer, frameCount: frameCount, volume: currentVolume)
            }
        }
        
        let initialCount = activeSounds.count
        activeSounds.removeAll(where: { $0.isFinished })
        let finishedCount = initialCount - activeSounds.count
        
        activeSoundsLock.unlock()
        
        if finishedCount > 0 {
            Logger.audio.debug("Removed \(finishedCount) finished sounds, \(self.activeSounds.count) still active")
        }
        
        // Set buffer size and enqueue
        buffer.pointee.mAudioDataByteSize = framesPerBuffer * audioFormat.mBytesPerFrame
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
    }
    
    // MARK: - Pitch Shifting
    
    /// Renders audio with pitch shifting via linear interpolation resampling
    private func renderWithPitch(sound: ActiveSound, outputBuffer: UnsafeMutablePointer<Float>, frameCount: Int, volume: Float) {
        // Semitones to playback rate conv
        let playbackRate = pow(2.0, sound.pitchOffset / 12.0)
        
        let initialFrame = sound.currentFrame
        var didFinish = false
        
        sound.pcmData.withUnsafeBufferPointer { pcmBuffer in
            for outputFrame in 0..<frameCount {
                // Calc source position
                let sourcePosition = Float(initialFrame) + Float(outputFrame) * playbackRate
                let sourceFrame = Int(sourcePosition)
                
                guard sourceFrame < sound.frameCount - 1 else {
                    sound.currentFrame = sound.frameCount
                    didFinish = true
                    break
                }
                
                // Linear interpolation fraction
                let fraction = sourcePosition - Float(sourceFrame)
                
                // Interpolate l+r channels
                let baseSample = sourceFrame * Int(channelCount)
                let nextSample = baseSample + Int(channelCount)
                
                // Left channel
                let leftCurrent = pcmBuffer[baseSample]
                let leftNext = pcmBuffer[nextSample]
                let leftInterpolated = leftCurrent + (leftNext - leftCurrent) * fraction
                
                // Right channel
                let rightCurrent = pcmBuffer[baseSample + 1]
                let rightNext = pcmBuffer[nextSample + 1]
                let rightInterpolated = rightCurrent + (rightNext - rightCurrent) * fraction
                
                // Mix into output buffer with volume
                let outputIndex = outputFrame * Int(channelCount)
                outputBuffer[outputIndex] += leftInterpolated * volume
                outputBuffer[outputIndex + 1] += rightInterpolated * volume
            }
        }
        
        if !didFinish {
            let framesConsumed = Int(Float(frameCount) * playbackRate)
            sound.currentFrame += framesConsumed
        }
    }
    
    private func primeBuffer(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        // Fill with silence and enqueue
        let bufferData = buffer.pointee.mAudioData
        memset(bufferData, 0, Int(framesPerBuffer * audioFormat.mBytesPerFrame))
        buffer.pointee.mAudioDataByteSize = framesPerBuffer * audioFormat.mBytesPerFrame
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
    }
    
    // MARK: - Public API
    
    func play(sound name: String, pitchVariation: Float = 0.0, latencyId: UUID? = nil) {
        guard isReady else {
            Logger.audio.warning("Playback blocked: audio system not ready")
            return
        }
        
        guard let pcmSound = soundLibrary[name] else {
            Logger.audio.warning("Sound file not found: '\(name)'")
            return
        }
        
        // Restart queue if stopped due to idle timeout
        if !isQueueRunning {
            restartQueue()
        } else {
            // Running, reset timer
            resetIdleTimer()
        }
        
        if ENABLE_LATENCY_MEASUREMENT {
            recordLatencyCheckpoint(latencyId, point: .bufferScheduling)
        }
        
        // Gen pitch offset [-variation, +variation]
        let pitchOffset: Float
        if pitchVariation > 0.0 {
            pitchOffset = Float.random(in: -pitchVariation...pitchVariation)
        } else {
            pitchOffset = 0.0
        }
        
        let activeSound = ActiveSound(
            pcmData: pcmSound.data,
            frameCount: pcmSound.frameCount,
            latencyId: latencyId,
            pitchOffset: pitchOffset
        )
        
        activeSoundsLock.lock()
        activeSounds.append(activeSound)
        activeSoundsLock.unlock()
    }
    
    func setVolume(_ newVolume: Float) {
        volumeLock.lock()
        volume = max(0.0, min(1.0, newVolume))
        volumeLock.unlock()
    }
    
    func getVolume() -> Float {
        volumeLock.lock()
        defer { volumeLock.unlock() }
        return volume
    }
    
    func preloadSounds(for mode: Mode) {
        soundLibrary.removeAll()
        
        guard let soundDirectory = resolveSoundDirectory(for: mode) else {
            Logger.audio.error("Sound directory not found for mode: '\(mode.name)'")
            return
        }
        
        do {
            let soundFiles = try FileManager.default.contentsOfDirectory(atPath: soundDirectory.path)
                .filter { $0.hasSuffix(".mp3") || $0.hasSuffix(".wav") }
            
            for file in soundFiles {
                let fileURL = soundDirectory.appendingPathComponent(file)
                if let pcmSound = loadPCMSound(from: fileURL) {
                    soundLibrary[file] = pcmSound
                }
            }
            
            Logger.audio.info("Preloaded \(self.soundLibrary.count) sounds for mode: '\(mode.name)'")
        } catch {
            Logger.audio.error("Failed to load sound files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sound Loading
    
    private func loadPCMSound(from url: URL) -> PCMSound? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            
            try file.read(into: buffer)
            
            // Convert to stereo Float32 array
            guard let pcmData = convertToStereoFloat(buffer: buffer) else {
                return nil
            }
            
            return PCMSound(data: pcmData, frameCount: Int(buffer.frameLength))
            
        } catch {
            Logger.audio.error("PCM decode failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func convertToStereoFloat(buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        let frameCount = Int(buffer.frameLength)
        let inputChannelCount = Int(buffer.format.channelCount)
        
        var stereoData: [Float] = []
        stereoData.reserveCapacity(frameCount * 2)
        
        if inputChannelCount == 1 {
            // Mono to stereo: duplicate channel
            let monoData = floatChannelData[0]
            for frame in 0..<frameCount {
                let sample = monoData[frame]
                stereoData.append(sample)  // Left
                stereoData.append(sample)  // Right
            }
        } else if inputChannelCount == 2 {
            // Stereo: interleave channels
            let leftData = floatChannelData[0]
            let rightData = floatChannelData[1]
            for frame in 0..<frameCount {
                stereoData.append(leftData[frame])   // Left
                stereoData.append(rightData[frame])  // Right
            }
        } else {
            // More than 2 channels: take first two
            let leftData = floatChannelData[0]
            let rightData = floatChannelData[1]
            for frame in 0..<frameCount {
                stereoData.append(leftData[frame])
                stereoData.append(rightData[frame])
            }
        }
        
        return stereoData
    }
    
    // MARK: - Device Management
    
    private func getDefaultOutputDeviceID() -> AudioDeviceID? {
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
        
        return status == noErr ? defaultDeviceID : nil
    }
    
    func getCurrentOutputDeviceUID() -> String {
        guard let defaultDeviceID = getDefaultOutputDeviceID() else {
            return Self.defaultDeviceUID
        }
        
        var deviceUID: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
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
        if uidStatus == noErr, let uid = deviceUID?.takeRetainedValue() as String? {
            return uid
        }
        return Self.defaultDeviceUID
    }
    
    func applyPerDeviceVolume() {
        let deviceUID = getCurrentOutputDeviceUID()
        let perDeviceVolumes = UserDefaults.standard.dictionary(forKey: UserDefaults.perDeviceVolumeKey) as? [String: Float] ?? [:]
        let savedVolume = perDeviceVolumes[deviceUID] ?? 0.5
        setVolume(savedVolume)
    }
    
    // MARK: - Helpers
    
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
}
