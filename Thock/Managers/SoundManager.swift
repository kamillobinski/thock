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
    private var audioQueueGeneration: UInt64 = 0 // Incremented on each reinitialization to detect stale references
    private var idleTimeoutTimer: DispatchSourceTimer?
    private let timerLock = NSLock()
    private let queueStateLock = NSLock() // Protects audioQueue, isQueueRunning, isReady, and audioQueueGeneration
    
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
        
        // Listen for audio device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioDeviceChange),
            name: .audioDeviceDidChange,
            object: nil
        )
        
        // Listen for system default device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSystemDefaultDeviceChange),
            name: .systemDefaultAudioDeviceDidChange,
            object: nil
        )
        
        // Listen for volume changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVolumeChange),
            name: .volumeDidChange,
            object: nil
        )
        
        // Listen for device list changes (conn/disconn)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceListChange),
            name: .audioDeviceListDidChange,
            object: nil
        )
        
        // Initialize volume from settings
        updateVolumeFromSettings()
        
        // Start monitoring audio device changes
        AudioDeviceManager.shared.startMonitoring()
    }
    
    @objc private func handleSettingsChange() {
        let newBufferSize = SettingsManager.shared.audioBufferSize
        
        // Handle buffer size change
        if newBufferSize != currentBufferSize {
            reinitializeAudioQueue(with: newBufferSize)
            return
        }
        
        // Reset idle timer with new timeout value
        queueStateLock.lock()
        let isRunning = isQueueRunning
        queueStateLock.unlock()
        
        if isRunning {
            resetIdleTimer()
        }
    }
    
    @objc private func handleAudioDeviceChange() {
        Logger.audio.info("Audio device selection changed, reinitializing audio queue")
        reinitializeAudioQueue(with: currentBufferSize)
        
        updateVolumeFromSettings(postNotification: true)
    }
    
    @objc private func handleSystemDefaultDeviceChange() {
        // only if selected "System Default"
        if SettingsEngine.shared.getSelectedAudioDeviceUID() == nil {
            Logger.audio.info("System default device changed while using System Default, reinitializing audio queue")
            reinitializeAudioQueue(with: currentBufferSize)
            
            updateVolumeFromSettings(postNotification: true)
        }
    }
    
    @objc private func handleVolumeChange() {
        updateVolumeFromSettings()
    }
    
    @objc private func handleDeviceListChange() {
        Logger.audio.info("Audio device list changed, checking if selected device status changed")
        
        // Check if specific device selected
        guard let selectedUID = SettingsEngine.shared.getSelectedAudioDeviceUID() else {
            return
        }
        
        queueStateLock.lock()
        let ready = isReady
        queueStateLock.unlock()
        
        // Check if the selected device is available
        if AudioDeviceManager.shared.findDevice(byUID: selectedUID) != nil {
            // Device reconnected
            if !ready {
                Logger.audio.info("Selected device '\(selectedUID)' reconnected, reinitializing audio queue")
                reinitializeAudioQueue(with: currentBufferSize)
                updateVolumeFromSettings(postNotification: true)
            } else {
                Logger.audio.debug("Selected device '\(selectedUID)' is available and system is ready")
            }
        } else {
            // Device disconnected
            if ready {
                Logger.audio.warning("Selected device '\(selectedUID)' disconnected, reinitializing to clean up audio queue")
                reinitializeAudioQueue(with: currentBufferSize)
            } else {
                Logger.audio.debug("Selected device '\(selectedUID)' is not available and audio was already not ready")
            }
        }
    }
    
    private func updateVolumeFromSettings(postNotification: Bool = false) {
        let deviceUID = getCurrentOutputDeviceUID()
        volume = SettingsEngine.shared.getVolume(for: deviceUID)
        if postNotification {
            NotificationCenter.default.post(name: .volumeDidChange, object: nil)
        }
    }
    
    private func reinitializeAudioQueue(with newBufferSize: UInt32) {
        // Cancel idle timer
        timerLock.lock()
        idleTimeoutTimer?.cancel()
        idleTimeoutTimer = nil
        timerLock.unlock()
        
        // Stop and dispose current audio queue
        queueStateLock.lock()
        audioQueueGeneration += 1
        let queue = audioQueue
        queueStateLock.unlock()
        
        if let queue = queue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
        
        // Update queue state
        queueStateLock.lock()
        currentBufferSize = newBufferSize
        framesPerBuffer = newBufferSize
        audioQueue = nil
        audioBuffers = []
        isQueueRunning = false
        isReady = false
        queueStateLock.unlock()
        
        // Clear active sounds
        activeSoundsLock.lock()
        activeSounds = []
        activeSoundsLock.unlock()
        
        // Reinitialize audio queue
        setupAudioFormat()
        configureLowLatencyAudio()
        createAudioQueue()
        
        Logger.audio.info("Audio queue reinitialized with buffer size: \(newBufferSize) frames")
    }
    
    /// Reinitializes the audio system after wake from sleep.
    func reinitializeAfterWake() {
        Logger.audio.info("Reinitializing audio system after wake from sleep")
        detectHardwareSampleRate()
        reinitializeAudioQueue(with: currentBufferSize)
        updateVolumeFromSettings(postNotification: true)
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
        defer { timerLock.unlock() }
        
        idleTimeoutTimer?.cancel()
        idleTimeoutTimer = nil
        setupIdleTimeoutTimer()
    }
    
    private func stopQueueIfIdle() {
        activeSoundsLock.lock()
        let isEmpty = activeSounds.isEmpty
        activeSoundsLock.unlock()
        
        queueStateLock.lock()
        let isRunning = isQueueRunning
        let queue = audioQueue
        let generation = audioQueueGeneration
        queueStateLock.unlock()
        
        guard isEmpty && isRunning, let queue = queue else { return }
        
        // Validate generation before calling core audio api
        queueStateLock.lock()
        let stillValid = (audioQueueGeneration == generation)
        queueStateLock.unlock()
        
        guard stillValid else {
            Logger.audio.debug("Queue was reinitialized, aborting stop")
            return
        }
        
        let status = AudioQueueStop(queue, false)
        if status == noErr {
            queueStateLock.lock()
            // Update state only if queue hasnt been reinitialized
            if audioQueueGeneration == generation {
                isQueueRunning = false
            }
            queueStateLock.unlock()
            
            let timeoutSeconds = SettingsEngine.shared.getIdleTimeoutSeconds()
            Logger.audio.info("Audio queue stopped after \(timeoutSeconds)s idle")
        } else {
            Logger.audio.error("Failed to stop audio queue: \(status)")
        }
    }
    
    private func restartQueue() {
        queueStateLock.lock()
        let isRunning = isQueueRunning
        let queue = audioQueue
        let generation = audioQueueGeneration
        queueStateLock.unlock()
        
        guard !isRunning, let queue = queue else { return }
        
        // Validate generation before calling core audio api
        queueStateLock.lock()
        let stillValid = (audioQueueGeneration == generation)
        queueStateLock.unlock()
        
        guard stillValid else {
            Logger.audio.debug("Queue was reinitialized, aborting restart")
            return
        }
        
        let status = AudioQueueStart(queue, nil)
        if status == noErr {
            queueStateLock.lock()
            // Update state only if queue hasnt been reinitialized
            if audioQueueGeneration == generation {
                isQueueRunning = true
            }
            queueStateLock.unlock()
            
            resetIdleTimer()
            Logger.audio.info("Audio queue restarted")
        } else {
            Logger.audio.error("Failed to restart audio queue: \(status)")
        }
    }
    
    // MARK: - Audio Format Setup
    private func detectHardwareSampleRate() {
        guard let preferredDeviceID = getPreferredOutputDeviceID() else {
            Logger.audio.warning("Preferred output device unavailable, using 44.1kHz fallback")
            return
        }
        let defaultDeviceID = preferredDeviceID
        
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
        guard let preferredDeviceID = getPreferredOutputDeviceID() else {
            Logger.audio.error("Cannot configure audio: preferred output device unavailable")
            return
        }
        let defaultDeviceID = preferredDeviceID
        
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
    
    /// Creates audio queue, ensuring it's always on the main thread's runloop
    private func createAudioQueue() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                createAudioQueueInternal()
            }
            return
        }
        createAudioQueueInternal()
    }
    
    /// Internal audio queue creation
    private func createAudioQueueInternal() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let status = AudioQueueNewOutput(
            &audioFormat,
            audioQueueCallback,
            selfPointer,
            CFRunLoopGetMain(),
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
        
        // Set output device for the audio queue (if not available, abort starting the queue)
        guard let deviceID = getPreferredOutputDeviceID() else {
            Logger.audio.error("Preferred audio device unavailable. Audio queue will not start")
            // dispose the queue
            AudioQueueDispose(queue, true)
            
            queueStateLock.lock()
            audioQueue = nil
            audioBuffers = []
            isReady = false
            queueStateLock.unlock()
            return
        }
        
        setAudioQueueOutputDevice(queue, deviceID: deviceID)
        
        // Start the queue
        let startStatus = AudioQueueStart(queue, nil)
        guard startStatus == noErr else {
            Logger.audio.error("Audio queue start failed with status: \(startStatus)")
            return
        }
        
        queueStateLock.lock()
        isQueueRunning = true
        isReady = true
        queueStateLock.unlock()
        
        timerLock.lock()
        setupIdleTimeoutTimer()
        timerLock.unlock()
        
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
        queueStateLock.lock()
        let ready = isReady
        queueStateLock.unlock()
        
        guard ready else {
            Logger.audio.warning("Playback blocked: audio system not ready")
            return
        }
        
        guard let pcmSound = soundLibrary[name] else {
            Logger.audio.warning("Sound file not found: '\(name)'")
            return
        }
        
        // Restart queue if stopped due to idle timeout
        queueStateLock.lock()
        let isRunning = isQueueRunning
        queueStateLock.unlock()
        
        if !isRunning {
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
    
    /// Returns the preferred output device ID based on user selection
    /// Returns nil if user selected a specific device that's not available (privacy protection)
    private func getPreferredOutputDeviceID() -> AudioDeviceID? {
        // Check user preference
        if let selectedUID = SettingsEngine.shared.getSelectedAudioDeviceUID() {
            if let device = AudioDeviceManager.shared.findDevice(byUID: selectedUID) {
                guard device.deviceID != 0 else {
                    Logger.audio.error("Selected device '\(selectedUID)' has invalid device ID. Stopping playback")
                    return nil
                }
                Logger.audio.debug("Using selected device: \(device.name) (\(device.id))")
                return device.deviceID
            }
            Logger.audio.error("Selected device '\(selectedUID)' not found. Stopping playback")
            return nil
        }
        
        // system default
        return getDefaultOutputDeviceID()
    }
    
    /// Sets the output device for an audio queue
    private func setAudioQueueOutputDevice(_ queue: AudioQueueRef, deviceID: AudioDeviceID) {
        // Get device uid
        var deviceUIDCF: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let uidStatus = AudioObjectGetPropertyData(
            deviceID,
            &uidAddress,
            0,
            nil,
            &uidSize,
            &deviceUIDCF
        )
        
        guard uidStatus == noErr, let uid = deviceUIDCF?.takeRetainedValue() else {
            Logger.audio.error("Failed to get device UID for AudioQueue routing: \(uidStatus)")
            return
        }
        
        // Set the output device on the audio queue
        var uidRef: CFString = uid
        let queueStatus = withUnsafePointer(to: &uidRef) { pointer in
            AudioQueueSetProperty(
                queue,
                kAudioQueueProperty_CurrentDevice,
                pointer,
                UInt32(MemoryLayout<CFString>.size)
            )
        }
        
        if queueStatus == noErr {
            Logger.audio.info("Audio queue routed to device: \(uid)")
        } else {
            Logger.audio.error("Failed to set audio queue device: \(queueStatus)")
        }
    }
    
    func getCurrentOutputDeviceUID() -> String {
        if let selectedUID = SettingsEngine.shared.getSelectedAudioDeviceUID() {
            // Return selected device UID if available
            if AudioDeviceManager.shared.findDevice(byUID: selectedUID) != nil {
                return selectedUID
            }
            // Device not found, keep the preference in case of reconnect or whatever
            Logger.audio.warning("Selected device '\(selectedUID)' not currently available")
        }
        
        // Fall back to system default for per-device volume tracking
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
