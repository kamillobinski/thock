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
    private var initRetryCount: Int = 0
    private var idleTimeoutTimer: DispatchSourceTimer?
    private let timerLock = NSLock()
    private let queueStateLock = NSLock() // Protects audioQueue, isQueueRunning, isReady, initRetryCount and audioQueueGeneration
    
    // MARK: - Audio Format
    private var sampleRate: Float64 = 44100.0
    private let channelCount: UInt32 = 2
    private let bitsPerChannel: UInt32 = 32
    private var framesPerBuffer: UInt32
    private var currentBufferSize: UInt32 = SettingsManager.shared.audioBufferSize
    
    private var audioFormat = AudioStreamBasicDescription()
    
    // MARK: - Sound Storage
    private var soundLibrary: [String: PCMSound] = [:]
    private var mouseSoundLibrary: [MouseButtonEvent: [PCMSound]] = [:]
    private var activeSounds: [ActiveSound] = []
    private let activeSoundsLock = NSLock()
    
    // MARK: - Spatial Audio (guarded by activeSoundsLock)
    private var spatialRenderer: SpatialRenderer?
    private var outputKind: OutputKind = .speakers
    private var spatialEnabled = SettingsEngine.shared.isSpatialAudioEnabled()
    private lazy var outputKindMonitor = OutputKindMonitor { [weak self] in
        self?.refreshOutputKind()
    }
    
    // MARK: - Idle State Tracking
    private var idleCallbackCount: Int = 0
    
    // MARK: - Volume Control
    private var volume: Float = 0.5
    private let volumeLock = NSLock()
    
    // MARK: - Models
    private final class PCMSound {
        /// Interleaved stereo
        let data: [Float]
        let frameCount: Int
        private var monoCache: [Float]?
        private let monoLock = NSLock()
        
        init(data: [Float], frameCount: Int) {
            self.data = data
            self.frameCount = frameCount
        }
        
        /// Mono downmix fed to the spatial mixer, built on first use so it costs no memory while
        /// spatial audio is off or playing through speakers
        var mono: [Float] {
            monoLock.lock()
            defer { monoLock.unlock() }
            if let monoCache { return monoCache }
            let mono = SpatialMath.monoDownmix(interleavedStereo: data)
            monoCache = mono
            return mono
        }
    }
    
    private class ActiveSound {
        let sound: PCMSound
        let rate: Double
        var sourcePosition: Double = 0
        let latencyId: UUID?
        var hasReportedPlayback: Bool = false
        /// Stereo gains for the dry path, (1, 1) unless panned for speakers
        let gains: (left: Float, right: Float)
        /// Spatial mixer input bus and its mono source when rendered through HRTF
        let bus: Int?
        let mono: [Float]?

        init(sound: PCMSound, rate: Double, latencyId: UUID?, gains: (left: Float, right: Float), bus: Int?, mono: [Float]?) {
            self.sound = sound
            self.rate = rate
            self.latencyId = latencyId
            self.gains = gains
            self.bus = bus
            self.mono = mono
        }

        var isFinished: Bool {
            sourcePosition >= Double(sound.frameCount)
        }
    }
    
    // MARK: - Initialization
    private init() {
        framesPerBuffer = currentBufferSize
        detectHardwareSampleRate()
        setupAudioFormat()
        configureLowLatencyAudio()
        rebuildSpatialRenderer()
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
        
        // Listen for spatial audio toggle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpatialAudioChange),
            name: .spatialAudioDidChange,
            object: nil
        )
        
        // Headphones plugged into or pulled from the built-in jack
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHeadphoneJackChange),
            name: .headphoneJackDidChange,
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
        resetIdleTimer()
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
    
    @objc private func handleSpatialAudioChange() {
        let enabled = SettingsEngine.shared.isSpatialAudioEnabled()
        
        activeSoundsLock.lock()
        spatialEnabled = enabled
        let needsRenderer = enabled && spatialRenderer == nil
        activeSoundsLock.unlock()
        
        // Disabling keeps the renderer so voices on it finish naturally, it costs nothing while idle
        if needsRenderer {
            buildSpatialRendererInBackground()
        }
        Logger.audio.info("Spatial audio \(enabled ? "enabled" : "disabled")")
    }
    
    @objc private func handleHeadphoneJackChange() {
        refreshOutputKind()
    }
    
    /// Creates the spatial renderer for the current format when spatial audio is on, drops it otherwise
    private func rebuildSpatialRenderer() {
        activeSoundsLock.lock()
        let enabled = spatialEnabled
        activeSoundsLock.unlock()
        
        // Built outside the lock, AU setup is slow
        let renderer = enabled ? SpatialRenderer.make(sampleRate: sampleRate, maxFrames: Int(framesPerBuffer)) : nil
        
        activeSoundsLock.lock()
        spatialRenderer = renderer
        // A play() racing the reinit can take a bus on the old renderer after activeSounds was cleared,
        // its index means nothing on the new one
        activeSounds.removeAll { $0.bus != nil }
        activeSoundsLock.unlock()
    }
    
    /// Builds the renderer off the main thread, the audio queue renders on the main run loop and
    /// AU setup takes longer than the queued buffers last
    private func buildSpatialRendererInBackground() {
        queueStateLock.lock()
        let generation = audioQueueGeneration
        queueStateLock.unlock()
        let rate = sampleRate
        let frames = Int(framesPerBuffer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, let renderer = SpatialRenderer.make(sampleRate: rate, maxFrames: frames) else { return }
            
            // Hold the queue state so a reinit cannot slip between the check and the swap
            self.queueStateLock.lock()
            defer { self.queueStateLock.unlock() }
            guard self.audioQueueGeneration == generation else { return } // reinit built its own
            
            self.activeSoundsLock.lock()
            if self.spatialEnabled && self.spatialRenderer == nil {
                self.spatialRenderer = renderer
            }
            self.activeSoundsLock.unlock()
        }
    }
    
    /// Resolves whether the routed device gets HRTF or the speaker pan
    private func refreshOutputKind() {
        let deviceID = getPreferredOutputDeviceID()
        outputKindMonitor.update(deviceID: deviceID)
        let kind = deviceID.map { HeadphoneDetector.shared.outputKind(for: $0) } ?? .speakers
        
        activeSoundsLock.lock()
        outputKind = kind
        activeSoundsLock.unlock()
        
        Logger.audio.info("Spatial output kind: \(String(describing: kind))")
    }
    
    private func updateVolumeFromSettings(postNotification: Bool = false) {
        let deviceUID = getCurrentOutputDeviceUID()
        let newVolume = SettingsEngine.shared.getVolume(for: deviceUID)
        
        volumeLock.lock()
        volume = newVolume
        volumeLock.unlock()
        
        if postNotification {
            NotificationCenter.default.post(name: .volumeDidChange, object: nil)
        }
    }
    
    private func reinitializeAudioQueue(with newBufferSize: UInt32, isRetry: Bool = false) {
        outputKindMonitor.update(deviceID: nil)
        detectHardwareSampleRate()
        
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
        if !isRetry {
            initRetryCount = 0
        }
        queueStateLock.unlock()
        
        // Clear active sounds
        activeSoundsLock.lock()
        activeSounds = []
        activeSoundsLock.unlock()
        
        // Reinitialize audio queue
        setupAudioFormat()
        configureLowLatencyAudio()
        rebuildSpatialRenderer()
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
        outputKindMonitor.update(deviceID: nil)
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
        
        let status = AudioQueueStop(queue, true)
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
        
        idleCallbackCount = 0
        // Re-prime all buffers
        Logger.audio.debug("Re-priming \(self.audioBuffers.count) buffers before restart")
        for buffer in audioBuffers {
            primeBuffer(buffer, queue: queue)
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
            Logger.audio.error("Failed to restart audio queue: \(status), queue is in bad state - reinitializing")
            
            // Queue failed to restart, full reinit to recover
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reinitializeAudioQueue(with: self.currentBufferSize)
            }
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
            Logger.audio.error("Preferred audio device unavailable, cleaning up and scheduling retry")
            AudioQueueDispose(queue, true)
            
            queueStateLock.lock()
            audioQueue = nil
            audioBuffers = []
            isReady = false
            let currentRetry = initRetryCount
            initRetryCount += 1
            queueStateLock.unlock()
            
            let delay = min(15.0, pow(2.0, Double(currentRetry))) // capped at 15
            Logger.audio.info("Scheduling device availability retry #\(currentRetry + 1) after \(delay)s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                Logger.audio.info("Retrying audio queue initialization for device availability (attempt #\(currentRetry + 1))")
                self.reinitializeAudioQueue(with: self.currentBufferSize, isRetry: true)
            }
            return
        }
        
        setAudioQueueOutputDevice(queue, deviceID: deviceID)
        refreshOutputKind()
        
        // Start the queue
        let startStatus = AudioQueueStart(queue, nil)
        guard startStatus == noErr else {
            Logger.audio.error("Audio queue start failed with status: \(startStatus), cleaning up and scheduling retry")
            AudioQueueDispose(queue, true)
            
            queueStateLock.lock()
            audioQueue = nil
            audioBuffers = []
            isReady = false
            isQueueRunning = false
            let currentRetry = initRetryCount
            initRetryCount += 1
            queueStateLock.unlock()
            
            let delay = min(15.0, pow(2.0, Double(currentRetry))) // capped at 15
            Logger.audio.info("Scheduling retry #\(currentRetry + 1) after \(delay)s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                Logger.audio.info("Retrying audio queue initialization (attempt #\(currentRetry + 1))")
                self.reinitializeAudioQueue(with: self.currentBufferSize, isRetry: true)
            }
            return
        }
        
        queueStateLock.lock()
        isQueueRunning = true
        isReady = true
        initRetryCount = 0
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
        
        // A renderer built for smaller buffers can't hold this block, its voices play dry instead
        let renderer = spatialRenderer.flatMap { $0.maxFrames >= frameCount ? $0 : nil }
        
        if activeSounds.isEmpty && (renderer?.isIdle ?? true) {
            // No active sounds or spatial tails, output silence and return early
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
        
        // No lock here coz float reads are atomic
        let currentVolume = volume
        
        renderer?.beginBlock(frames: frameCount)
        
        for sound in activeSounds {
            // Report playback started on first render
            if ENABLE_LATENCY_MEASUREMENT && !sound.hasReportedPlayback {
                sound.hasReportedPlayback = true
                recordLatencyCheckpoint(sound.latencyId, point: .playbackStarted)
                completeLatencyMeasurement(sound.latencyId)
            }
            
            if let bus = sound.bus, let mono = sound.mono, let renderer {
                // Mono into the spatial mixer bus, volume is applied to the mixer output
                _ = mono.withUnsafeBufferPointer { pcm in
                    Resampler.mix(
                        source: pcm, channels: 1, frameCount: sound.sound.frameCount,
                        position: &sound.sourcePosition, rate: sound.rate,
                        into: renderer.busInput(bus), outChannels: 1, outFrames: frameCount,
                        gains: (1, 1)
                    )
                }
                if sound.isFinished {
                    renderer.releaseBus(bus)
                }
            } else {
                _ = sound.sound.data.withUnsafeBufferPointer { pcm in
                    Resampler.mix(
                        source: pcm, channels: Int(channelCount), frameCount: sound.sound.frameCount,
                        position: &sound.sourcePosition, rate: sound.rate,
                        into: outputBuffer, outChannels: Int(channelCount), outFrames: frameCount,
                        gains: (sound.gains.left * currentVolume, sound.gains.right * currentVolume)
                    )
                }
            }
        }
        
        renderer?.render(frames: frameCount, into: outputBuffer, gain: currentVolume * SpatialRenderer.calibrationGain)
        
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
    
    private func primeBuffer(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        // Fill with silence and enqueue
        let bufferData = buffer.pointee.mAudioData
        memset(bufferData, 0, Int(framesPerBuffer * audioFormat.mBytesPerFrame))
        buffer.pointee.mAudioDataByteSize = framesPerBuffer * audioFormat.mBytesPerFrame
        AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
    }
    
    // MARK: - Public API
    
    func play(sound name: String, pitchVariation: Float = 0.0, latencyId: UUID? = nil, position: SoundPosition? = nil) {
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
        let stillReady = isReady // could have changed during device reinit
        queueStateLock.unlock()
        
        if stillReady && !isRunning {
            restartQueue()
        } else if stillReady && isRunning {
            resetIdleTimer()
        } else {
            Logger.audio.debug("Playback blocked: audio system became not ready during play()")
            return
        }
        
        if ENABLE_LATENCY_MEASUREMENT {
            recordLatencyCheckpoint(latencyId, point: .bufferScheduling)
        }
        
        enqueue(pcmSound, pitchVariation: pitchVariation, latencyId: latencyId, position: position)
    }

    /// Creates a voice with a random pitch offset in [-variation, +variation] and starts it on the next callback
    private func enqueue(_ pcmSound: PCMSound, pitchVariation: Float, latencyId: UUID?, position: SoundPosition?) {
        let pitchOffset: Float = pitchVariation > 0.0 ? Float.random(in: -pitchVariation...pitchVariation) : 0.0
        // Semitones to playback rate
        let rate = pitchOffset == 0.0 ? 1.0 : Double(pow(2.0, pitchOffset / 12.0))

        // The mono downmix is only needed on the HRTF path, build it outside the lock the audio thread takes
        activeSoundsLock.lock()
        let wantsMono = position != nil && spatialEnabled && outputKind == .headphones
        activeSoundsLock.unlock()
        let mono = wantsMono ? pcmSound.mono : nil

        activeSoundsLock.lock()
        let renderer = spatialRenderer
        // Without a mono source (settings changed in between) the voice takes the speaker pan
        let route = SpatialMath.route(position: position, spatialEnabled: spatialEnabled, outputKind: outputKind) {
            mono == nil ? nil : renderer?.acquireBus(position: $0)
        }
        activeSounds.append(ActiveSound(sound: pcmSound, rate: rate, latencyId: latencyId,
                                        gains: route.gains, bus: route.bus, mono: route.bus == nil ? nil : mono))
        activeSoundsLock.unlock()
    }
    
    func preloadSounds(for soundpack: Soundpack) {
        soundLibrary.removeAll()
        
        guard let soundDirectory = resolveSoundDirectory(for: soundpack) else {
            Logger.audio.error("Sound directory not found for soundpack: '\(soundpack.name)'")
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
            
            Logger.audio.info("Preloaded \(self.soundLibrary.count) sounds for soundpack: '\(soundpack.name)'")
        } catch {
            Logger.audio.error("Failed to load sound files: \(error.localizedDescription)")
        }
    }
    
    /// Preloads mouse sounds from a downloaded soundpack.
    /// Config sounds keys: "left" (down/up arrays) and "right" (down/up arrays).
    func preloadMouseSoundsFromPack(for soundpack: Soundpack, config: SoundpackConfig) {
        mouseSoundLibrary.removeAll()
        
        guard let dir = resolveSoundDirectory(for: soundpack) else {
            Logger.audio.error("Mouse sound directory not found for soundpack: '\(soundpack.name)'")
            return
        }
        
        let mapping: [(MouseButtonEvent, String, Bool)] = [
            (.leftDown,  "left",  false),
            (.leftUp,    "left",  true),
            (.rightDown, "right", false),
            (.rightUp,   "right", true)
        ]
        
        for (event, key, isUp) in mapping {
            guard let keySound = config.sounds[key] else { continue }
            let fileNames = isUp ? keySound.up : keySound.down
            let sounds = fileNames.compactMap { loadPCMSound(from: dir.appendingPathComponent($0)) }
            if !sounds.isEmpty {
                mouseSoundLibrary[event] = sounds
            }
        }
        
        Logger.audio.info("Preloaded mouse sounds: \(self.mouseSoundLibrary.count) events for '\(soundpack.name)'")
    }
    
    /// Plays a sound for the specified mouse button event.
    /// - Parameter location: Cursor location in global CG coordinates, used for spatial audio
    func playMouseSound(for event: MouseButtonEvent, location: CGPoint? = nil) {
        guard let sounds = mouseSoundLibrary[event], let sound = sounds.randomElement() else {
            Logger.audio.warning("Mouse sound not found for event: \(event)")
            return
        }
        
        queueStateLock.lock()
        let ready = isReady
        queueStateLock.unlock()
        
        guard ready else {
            Logger.audio.warning("Mouse sound blocked: audio system not ready")
            return
        }
        
        // Restart queue if stopped due to idle timeout
        queueStateLock.lock()
        let isRunning = isQueueRunning
        let stillReady = isReady
        queueStateLock.unlock()
        
        if stillReady && !isRunning {
            restartQueue()
        } else if stillReady && isRunning {
            resetIdleTimer()
        } else {
            Logger.audio.debug("Mouse sound blocked: audio system became not ready")
            return
        }
        
        let position = location.map {
            SpatialMath.mousePosition(location: $0, displayBounds: SpatialMath.desktopBounds(activeDisplayBounds()),
                                     width: SettingsEngine.shared.getSpatialWidth())
        }
        enqueue(sound, pitchVariation: SettingsEngine.shared.getPitchVariation(), latencyId: nil, position: position)
    }

    private func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map { CGDisplayBounds($0) }
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
    
    /// Validates that a device ID is still valid and available
    /// - Parameter deviceID: The device ID to validate
    /// - Returns: true if device is valid, false otherwise
    private func isDeviceValid(_ deviceID: AudioDeviceID) -> Bool {
        guard deviceID != 0 else { return false }
        
        // Check if device exists
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Check if property exists
        let hasProperty = AudioObjectHasProperty(deviceID, &propertyAddress)
        return hasProperty
    }
    
    /// Returns the preferred output device ID based on user selection
    /// Returns nil if user selected a specific device that's not available (privacy protection)
    private func getPreferredOutputDeviceID() -> AudioDeviceID? {
        // Check user preference
        if let selectedUID = SettingsEngine.shared.getSelectedAudioDeviceUID() {
            if let device = AudioDeviceManager.shared.findDevice(byUID: selectedUID) {
                let deviceID = device.deviceID
                
                guard deviceID != 0 else {
                    Logger.audio.error("Selected device '\(selectedUID)' has invalid device ID. Stopping playback")
                    return nil
                }
                
                // Validate device still exists before returning
                guard isDeviceValid(deviceID) else {
                    Logger.audio.error("Selected device '\(selectedUID)' is no longer valid. Stopping playback")
                    return nil
                }
                
                Logger.audio.debug("Using selected device: \(device.name) (\(device.id))")
                return deviceID
            }
            Logger.audio.error("Selected device '\(selectedUID)' not found. Stopping playback")
            return nil
        }
        
        if let defaultDeviceID = getDefaultOutputDeviceID() {
            // Validate before returning
            guard isDeviceValid(defaultDeviceID) else {
                Logger.audio.error("System default device is no longer valid")
                return nil
            }
            return defaultDeviceID
        }
        
        return nil
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
    
    private func resolveSoundDirectory(for soundpack: Soundpack) -> URL? {
        let isCustom = soundpack.path.hasPrefix("Soundpacks/")
        let trimmedPath = soundpack.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if isCustom {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Thock/\(trimmedPath)", isDirectory: true)
        } else {
            return Bundle.main.resourceURL?
                .appendingPathComponent(trimmedPath, isDirectory: true)
        }
    }
}
