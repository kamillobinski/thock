import Foundation
import AudioToolbox
import Accelerate
import OSLog

/// Renders positioned voices through Apple's AUSpatialMixer for headphone output.
/// Created and destroyed while the audio queue is not rendering. acquireBus/releaseBus are called
/// under the owner's lock, never concurrently with render. beginBlock, busInput writes and render
/// run in that order on the audio callback.
final class SpatialRenderer {
    static let busCount = 32
    /// How long a released bus keeps rendering silence so its HRTF filter tail and the mixer's
    /// internal latency drain before the bus is reused
    static let tailDuration: Double = 0.02
    /// Level match between the HRTF path and the dry path. The headphone renderer measured
    /// -2.48 dB per ear at center vs. the dry mono signal (SpatialRendererTests.calibrationMatchesDryLevel)
    static let calibrationGain: Float = 1.330
    /// Algorithms whose reported latency exceeds this are skipped
    static let maxLatency: Double = 0.002

    private(set) var latency: Double = 0
    private(set) var algorithm: AUSpatializationAlgorithm = .spatializationAlgorithm_UseOutputType
    /// Tail length in frames at the configured sample rate, includes the mixer latency
    private(set) var tailFrames = 0
    /// Largest block the bus inputs can hold
    let maxFrames: Int
    fileprivate let inputs: UnsafeMutablePointer<Float>

    private var unit: AudioUnit?
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let outputList: UnsafeMutableAudioBufferListPointer
    private var inUse = [Bool](repeating: false, count: busCount)
    private var tail = [Int](repeating: 0, count: busCount)
    private var activeCount = 0
    private var tailingCount = 0
    private var sampleTime: Float64 = 0
    /// Frames in the block being rendered, a bus released mid-block starts its tail after it
    private var blockFrames = 0

    var isIdle: Bool { activeCount == 0 && tailingCount == 0 }

    // MARK: - Creation

    /// Builds a renderer with the best spatial algorithm that fits the latency budget
    static func make(sampleRate: Double, maxFrames: Int) -> SpatialRenderer? {
        let algorithms: [AUSpatializationAlgorithm] = [
            .spatializationAlgorithm_UseOutputType,
            .spatializationAlgorithm_HRTFHQ,
            .spatializationAlgorithm_HRTF
        ]

        for algorithm in algorithms {
            let renderer = SpatialRenderer(maxFrames: maxFrames)
            guard renderer.configure(sampleRate: sampleRate, algorithm: algorithm) else { continue }

            if renderer.latency <= maxLatency {
                Logger.audio.info("Spatial renderer ready: algorithm \(algorithm.rawValue), latency \(String(format: "%.2f", renderer.latency * 1000))ms")
                return renderer
            }
            Logger.audio.info("Spatial algorithm \(algorithm.rawValue) latency \(String(format: "%.2f", renderer.latency * 1000))ms over budget, trying next")
        }

        Logger.audio.error("No spatial algorithm available within latency budget")
        return nil
    }

    private init(maxFrames: Int) {
        self.maxFrames = maxFrames
        inputs = .allocate(capacity: Self.busCount * maxFrames)
        inputs.initialize(repeating: 0, count: Self.busCount * maxFrames)
        left = .allocate(capacity: maxFrames)
        left.initialize(repeating: 0, count: maxFrames)
        right = .allocate(capacity: maxFrames)
        right.initialize(repeating: 0, count: maxFrames)
        outputList = AudioBufferList.allocate(maximumBuffers: 2)
    }

    deinit {
        if let unit {
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
        inputs.deallocate()
        left.deallocate()
        right.deallocate()
        free(outputList.unsafeMutablePointer)
    }

    private func configure(sampleRate: Double, algorithm: AUSpatializationAlgorithm) -> Bool {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Mixer,
            componentSubType: kAudioUnitSubType_SpatialMixer,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        guard let component = AudioComponentFindNext(nil, &description) else {
            Logger.audio.error("AUSpatialMixer component not found")
            return false
        }

        self.algorithm = algorithm
        var instance: AudioUnit?
        guard check(AudioComponentInstanceNew(component, &instance), "create"), let instance else { return false }
        unit = instance

        var busCount = UInt32(Self.busCount)
        var maxFramesPerSlice = UInt32(max(maxFrames, 4096))
        var outputType = AUSpatialMixerOutputType.spatialMixerOutputType_Headphones.rawValue
        var noReverb: UInt32 = 0
        var monoFormat = Self.format(sampleRate: sampleRate, channels: 1)
        var stereoFormat = Self.format(sampleRate: sampleRate, channels: 2)

        guard setProperty(kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, "bus count"),
              setProperty(kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, "max frames"),
              setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &stereoFormat, "output format"),
              setProperty(kAudioUnitProperty_SpatialMixerOutputType, kAudioUnitScope_Global, 0, &outputType, "output type"),
              setProperty(kAudioUnitProperty_UsesInternalReverb, kAudioUnitScope_Global, 0, &noReverb, "reverb")
        else { return false }

        let refCon = Unmanaged.passUnretained(self).toOpaque()

        for bus in 0..<UInt32(Self.busCount) {
            var algorithmValue = algorithm.rawValue
            var sourceMode = AUSpatialMixerSourceMode.spatialMixerSourceMode_PointSource.rawValue
            // Reference distance equals source distance, so there is no distance attenuation
            var distance = MixerDistanceParams(mReferenceDistance: 1, mMaxDistance: 1000, mMaxAttenuation: 0)
            var callback = AURenderCallbackStruct(inputProc: spatialInputCallback, inputProcRefCon: refCon)

            guard setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, bus, &monoFormat, "input format"),
                  setProperty(kAudioUnitProperty_SpatializationAlgorithm, kAudioUnitScope_Input, bus, &algorithmValue, "algorithm"),
                  setProperty(kAudioUnitProperty_SpatialMixerSourceMode, kAudioUnitScope_Input, bus, &sourceMode, "source mode"),
                  setProperty(kAudioUnitProperty_SpatialMixerDistanceParams, kAudioUnitScope_Input, bus, &distance, "distance"),
                  setProperty(kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, bus, &callback, "callback")
            else { return false }
        }

        guard check(AudioUnitInitialize(instance), "initialize") else { return false }

        for bus in 0..<Self.busCount {
            setParameter(AudioUnitParameterID(k3DMixerParam_Distance), bus: bus, value: 1)
            setParameter(AudioUnitParameterID(k3DMixerParam_DryWetReverbBlend), bus: bus, value: 0)
            setParameter(AudioUnitParameterID(k3DMixerParam_BusEnable), bus: bus, value: 0)
        }

        var reportedLatency: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        if AudioUnitGetProperty(instance, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &reportedLatency, &size) == noErr {
            latency = reportedLatency
        }
        tailFrames = Int(((Self.tailDuration + latency) * sampleRate).rounded(.up))
        return true
    }

    private static func format(sampleRate: Double, channels: UInt32) -> AudioStreamBasicDescription {
        let bytes = UInt32(MemoryLayout<Float>.size)
        return AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: bytes,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytes,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    // MARK: - Buses

    /// Claims a free bus at the given position, nil when all buses are busy or tailing
    func acquireBus(position: SoundPosition) -> Int? {
        guard let bus = (0..<Self.busCount).first(where: { !inUse[$0] && tail[$0] == 0 }) else { return nil }

        setParameter(AudioUnitParameterID(k3DMixerParam_Azimuth), bus: bus, value: position.azimuth)
        setParameter(AudioUnitParameterID(k3DMixerParam_Elevation), bus: bus, value: position.elevation)
        setParameter(AudioUnitParameterID(k3DMixerParam_BusEnable), bus: bus, value: 1)

        inUse[bus] = true
        activeCount += 1
        return bus
    }

    /// Returns a bus to the pool once its HRTF tail has rendered out
    func releaseBus(_ bus: Int) {
        guard inUse[bus] else { return }
        inUse[bus] = false
        activeCount -= 1
        // The rest of the current block still carries this voice, the tail starts after it
        tail[bus] = tailFrames + blockFrames
        tailingCount += 1
    }

    /// Mono input for a bus, valid for the current block
    func busInput(_ bus: Int) -> UnsafeMutablePointer<Float> {
        inputs + bus * maxFrames
    }

    // MARK: - Rendering

    /// Clears the inputs of every live bus before voices write into them
    func beginBlock(frames: Int) {
        blockFrames = frames
        guard !isIdle, frames <= maxFrames else { return }
        for bus in 0..<Self.busCount where inUse[bus] || tail[bus] > 0 {
            memset(busInput(bus), 0, frames * MemoryLayout<Float>.size)
        }
    }

    /// Spatializes all live buses and adds the result into an interleaved stereo buffer
    func render(frames: Int, into out: UnsafeMutablePointer<Float>, gain: Float) {
        guard !isIdle, let unit, frames <= maxFrames else { return }

        let byteSize = UInt32(frames * MemoryLayout<Float>.size)
        outputList[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: UnsafeMutableRawPointer(left))
        outputList[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: UnsafeMutableRawPointer(right))

        var flags = AudioUnitRenderActionFlags()
        var timeStamp = AudioTimeStamp()
        timeStamp.mSampleTime = sampleTime
        timeStamp.mFlags = .sampleTimeValid
        sampleTime += Float64(frames)

        let status = AudioUnitRender(unit, &flags, &timeStamp, 0, UInt32(frames), outputList.unsafeMutablePointer)
        if status == noErr {
            var scale = gain
            vDSP_vsma(left, 1, &scale, out, 2, out, 2, vDSP_Length(frames))
            vDSP_vsma(right, 1, &scale, out + 1, 2, out + 1, 2, vDSP_Length(frames))
        }

        blockFrames = 0
        
        guard tailingCount > 0 else { return }
        for bus in 0..<Self.busCount where tail[bus] > 0 {
            tail[bus] -= frames
            if tail[bus] <= 0 {
                tail[bus] = 0
                tailingCount -= 1
                setParameter(AudioUnitParameterID(k3DMixerParam_BusEnable), bus: bus, value: 0)
            }
        }
    }

    // MARK: - Helpers

    private func setParameter(_ parameter: AudioUnitParameterID, bus: Int, value: Float) {
        guard let unit else { return }
        AudioUnitSetParameter(unit, parameter, kAudioUnitScope_Input, AudioUnitElement(bus), value, 0)
    }

    private func setProperty<T>(_ property: AudioUnitPropertyID, _ scope: AudioUnitScope, _ element: AudioUnitElement, _ value: inout T, _ name: String) -> Bool {
        guard let unit else { return false }
        let status = withUnsafePointer(to: &value) {
            AudioUnitSetProperty(unit, property, scope, element, $0, UInt32(MemoryLayout<T>.size))
        }
        return check(status, name)
    }

    private func check(_ status: OSStatus, _ step: String) -> Bool {
        if status != noErr {
            Logger.audio.error("AUSpatialMixer \(step) failed: \(status)")
        }
        return status == noErr
    }
}

/// Feeds each spatial mixer input bus from its preallocated mono buffer
private let spatialInputCallback: AURenderCallback = { refCon, _, _, busNumber, frameCount, ioData in
    let renderer = Unmanaged<SpatialRenderer>.fromOpaque(refCon).takeUnretainedValue()
    guard let ioData, let destination = UnsafeMutableAudioBufferListPointer(ioData)[0].mData else { return noErr }
    let frames = min(Int(frameCount), renderer.maxFrames)
    memcpy(destination, renderer.inputs + Int(busNumber) * renderer.maxFrames, frames * MemoryLayout<Float>.size)
    return noErr
}
