import Foundation
import CoreAudio
import OSLog

// MARK: - Configuration

/// Toggle this to enable/disable latency measurement
let ENABLE_LATENCY_MEASUREMENT = false

// MARK: - Measurement Points
enum LatencyPoint: String {
    case keyEventReceived = "Key Event Received"
    case soundEngineInvoked = "Sound Engine Invoked"
    case soundSelected = "Sound Selected"
    case bufferScheduling = "Buffer Scheduling"
    case playbackStarted = "Playback Started"
}

// MARK: - Latency Tracker
class LatencyTracker {
    static let shared = LatencyTracker()
    
    private(set) var measuredHardwareLatencyMs: Double = 0.0
    private var measurements: [UUID: LatencyMeasurement] = [:]
    private let queue = DispatchQueue(label: "dev.kamillobinski.Thock.latency", qos: .userInteractive)
    
    private struct LatencyMeasurement {
        let id: UUID
        let startTime: CFAbsoluteTime
        var checkpoints: [LatencyPoint: CFAbsoluteTime] = [:]
    }
    
    private init() {}
    
    /// Update the measured hardware latency
    func setHardwareLatency(_ latencyMs: Double) {
        queue.async { [weak self] in
            self?.measuredHardwareLatencyMs = latencyMs
        }
    }
    
    // MARK: - Public API
    
    /// Start a new latency measurement session
    /// - Returns: UUID to track this specific measurement
    func start() -> UUID? {
        guard ENABLE_LATENCY_MEASUREMENT else { return nil }
        
        let id = UUID()
        let measurement = LatencyMeasurement(id: id, startTime: CFAbsoluteTimeGetCurrent())
        
        queue.async { [weak self] in
            self?.measurements[id] = measurement
        }
        
        return id
    }
    
    /// Record a checkpoint in the latency measurement
    /// - Parameters:
    ///   - id: The measurement session UUID
    ///   - point: The checkpoint being recorded
    func checkpoint(_ id: UUID?, point: LatencyPoint) {
        guard ENABLE_LATENCY_MEASUREMENT, let id = id else { return }
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        queue.async { [weak self] in
            self?.measurements[id]?.checkpoints[point] = timestamp
        }
    }
    
    /// Complete the measurement and log results
    /// - Parameter id: The measurement session UUID
    func complete(_ id: UUID?) {
        guard ENABLE_LATENCY_MEASUREMENT, let id = id else { return }
        
        queue.async { [weak self] in
            guard let self = self,
                  let measurement = self.measurements[id] else { return }
            
            let orderedPoints: [LatencyPoint] = [
                .keyEventReceived,
                .soundEngineInvoked,
                .soundSelected,
                .bufferScheduling,
                .playbackStarted
            ]
            
            // Calculate deltas between checkpoints
            var checkpointLatencies: [(LatencyPoint, Double)] = []
            var previousTime = measurement.startTime
            
            for point in orderedPoints {
                if let currentTime = measurement.checkpoints[point] {
                    let delta = (currentTime - previousTime) * 1000.0 // Convert to ms
                    checkpointLatencies.append((point, delta))
                    previousTime = currentTime
                }
            }
            
            let totalLatency = checkpointLatencies.reduce(0.0) { $0 + $1.1 }
            
            // Log the results
            self.logResults(totalLatency: totalLatency, checkpoints: checkpointLatencies)
            
            // Clean up
            self.measurements.removeValue(forKey: id)
        }
    }
    
    // MARK: - Private Helpers
    
    private func logResults(totalLatency: Double, checkpoints: [(LatencyPoint, Double)]) {
        var output = "Audio Engine Latency:\n\n"
        for (point, latency) in checkpoints {
            let paddedLabel = point.rawValue.padding(toLength: 18, withPad: " ", startingAt: 0)
            output += String(format: "%@  %.2f ms\n", paddedLabel, latency)
        }
        let totalLabel = "Total (measured):".padding(toLength: 18, withPad: " ", startingAt: 0)
        output += String(format: "%@  %.2f ms\n", totalLabel, totalLatency)
        
        if measuredHardwareLatencyMs > 0 {
            let totalRealLatency = totalLatency + measuredHardwareLatencyMs
            let realLabel = "Total (real):".padding(toLength: 18, withPad: " ", startingAt: 0)
            output += String(format: "%@  %.2f ms (measured + HW %.2f ms)\n\n", realLabel, totalRealLatency, measuredHardwareLatencyMs)
        } else {
            output += "\n"
        }
        
        Logger.latency.debug("\(output)")
    }
}

// MARK: - Convenience Functions

/// Start measuring latency (no-op if disabled)
@inline(__always)
func startLatencyMeasurement() -> UUID? {
    LatencyTracker.shared.start()
}

/// Record a latency checkpoint (no-op if disabled)
@inline(__always)
func recordLatencyCheckpoint(_ id: UUID?, point: LatencyPoint) {
    LatencyTracker.shared.checkpoint(id, point: point)
}

/// Complete latency measurement and log results (no-op if disabled)
@inline(__always)
func completeLatencyMeasurement(_ id: UUID?) {
    LatencyTracker.shared.complete(id)
}

/// Measures and reports the actual audio latency from the hardware.
/// - Parameter deviceID: The audio device to measure
/// - Returns: The total hardware latency in milliseconds
@discardableResult
func measureHardwareLatency(deviceID: AudioDeviceID) -> Double {
    var sampleRate: Float64 = 0
    var dataSize = UInt32(MemoryLayout<Float64>.size)
    var sampleRateAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyNominalSampleRate,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    // Get sample rate
    AudioObjectGetPropertyData(
        deviceID,
        &sampleRateAddress,
        0,
        nil,
        &dataSize,
        &sampleRate
    )
    
    // Get actual buffer size
    var actualBufferSize: UInt32 = 0
    var bufferSizeSize = UInt32(MemoryLayout<UInt32>.size)
    var bufferAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyBufferFrameSize,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    AudioObjectGetPropertyData(
        deviceID,
        &bufferAddress,
        0,
        nil,
        &bufferSizeSize,
        &actualBufferSize
    )
    
    // Get device latency
    var deviceLatency: UInt32 = 0
    var latencySize = UInt32(MemoryLayout<UInt32>.size)
    var latencyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyLatency,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    AudioObjectGetPropertyData(
        deviceID,
        &latencyAddress,
        0,
        nil,
        &latencySize,
        &deviceLatency
    )
    
    // Get safety offset
    var safetyOffset: UInt32 = 0
    var safetySize = UInt32(MemoryLayout<UInt32>.size)
    var safetyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertySafetyOffset,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )
    
    AudioObjectGetPropertyData(
        deviceID,
        &safetyAddress,
        0,
        nil,
        &safetySize,
        &safetyOffset
    )
    
    // Calculate latencies in ms
    let bufferLatencyMs = (Double(actualBufferSize) / sampleRate) * 1000.0
    let deviceLatencyMs = (Double(deviceLatency) / sampleRate) * 1000.0
    let safetyOffsetMs = (Double(safetyOffset) / sampleRate) * 1000.0
    let totalHardwareLatencyMs = bufferLatencyMs + deviceLatencyMs + safetyOffsetMs
    
    let sampleLabel = "Sample Rate:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let bufferLabel = "Buffer Size:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let ioLabel = "- I/O Latency:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let deviceLabel = "- Device Latency:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let safetyLabel = "- Safety Offset:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let totalLabel = "Total:".padding(toLength: 20, withPad: " ", startingAt: 0)
    
    var output = "Audio Hardware Latency:\n\n"
    output += String(format: "%@%.1f kHz\n", sampleLabel, sampleRate / 1000.0)
    output += String(format: "%@%d frames\n", bufferLabel, actualBufferSize)
    output += String(format: "%@%.2f ms\n", ioLabel, bufferLatencyMs)
    output += String(format: "%@%.2f ms\n", deviceLabel, deviceLatencyMs)
    output += String(format: "%@%.2f ms\n", safetyLabel, safetyOffsetMs)
    output += String(format: "%@%.2f ms\n", totalLabel, totalHardwareLatencyMs)
    
    Logger.latency.debug("\(output)")
    
    LatencyTracker.shared.setHardwareLatency(totalHardwareLatencyMs)
    
    return totalHardwareLatencyMs
}
