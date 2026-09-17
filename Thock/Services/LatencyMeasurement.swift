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
    
    /// How long a measurement may sit unfinished before it is dropped.
    private static let staleMeasurementLifetime: CFAbsoluteTime = 5.0

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
        let startedAt = CFAbsoluteTimeGetCurrent()
        let measurement = LatencyMeasurement(id: id, startTime: startedAt)
        
        queue.async { [weak self] in
            guard let self = self else { return }
            // complete() only runs when a sound actually renders, so a keystroke that
            // never resolves to a sound would otherwise leave its entry behind forever.
            self.pruneMeasurements(olderThan: startedAt - Self.staleMeasurementLifetime)
            self.measurements[id] = measurement
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
    
    /// Drops measurements that never completed. Only called on `queue`.
    private func pruneMeasurements(olderThan cutoff: CFAbsoluteTime) {
        measurements = measurements.filter { $0.value.startTime >= cutoff }
    }

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
            let realLabel = "Total (estimated):".padding(toLength: 18, withPad: " ", startingAt: 0)
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

// MARK: - CoreAudio Property Reading

/// Reads a Float64 property, returning nil when the query fails.
private func readAudioPropertyFloat64(
    _ deviceID: AudioDeviceID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope
) -> Float64? {
    var value: Float64 = 0
    var size = UInt32(MemoryLayout<Float64>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
        return nil
    }
    return value
}

/// Reads a UInt32 property, returning nil when the query fails.
private func readAudioPropertyUInt32(
    _ deviceID: AudioDeviceID,
    _ selector: AudioObjectPropertySelector,
    scope: AudioObjectPropertyScope
) -> UInt32? {
    var value: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: scope,
        mElement: kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr else {
        return nil
    }
    return value
}

/// Estimates the device contribution to latency from reported hardware properties.
/// This does not measure end-to-end playback or the current AudioQueue depth.
/// - Returns: The estimate in milliseconds, or 0 when a property is unavailable.
@discardableResult
func measureHardwareLatency(deviceID: AudioDeviceID) -> Double {
    // Every query below used to ignore its status, so a failed sample rate lookup left
    // this at zero and each division produced inf or NaN, which then propagated into the
    // reported total as the hardware term.
    guard let sampleRate = readAudioPropertyFloat64(
        deviceID,
        kAudioDevicePropertyNominalSampleRate,
        scope: kAudioObjectPropertyScopeGlobal
    ), sampleRate.isFinite, sampleRate > 0 else {
        Logger.latency.error("Cannot measure hardware latency: nominal sample rate unavailable")
        LatencyTracker.shared.setHardwareLatency(0)
        return 0
    }
    
    guard let actualBufferSize = readAudioPropertyUInt32(
        deviceID,
        kAudioDevicePropertyBufferFrameSize,
        scope: kAudioObjectPropertyScopeGlobal
    ), let deviceLatency = readAudioPropertyUInt32(
        deviceID,
        kAudioDevicePropertyLatency,
        scope: kAudioDevicePropertyScopeOutput
    ), let safetyOffset = readAudioPropertyUInt32(
        deviceID,
        kAudioDevicePropertySafetyOffset,
        scope: kAudioDevicePropertyScopeOutput
    ) else {
        Logger.latency.error("Cannot estimate hardware latency: device timing property unavailable")
        LatencyTracker.shared.setHardwareLatency(0)
        return 0
    }

    func milliseconds(forFrames frames: UInt32) -> Double {
        (Double(frames) / sampleRate) * 1000.0
    }
    
    let bufferLatencyMs = milliseconds(forFrames: actualBufferSize)
    let deviceLatencyMs = milliseconds(forFrames: deviceLatency)
    let safetyOffsetMs = milliseconds(forFrames: safetyOffset)
    let totalHardwareLatencyMs = bufferLatencyMs + deviceLatencyMs + safetyOffsetMs
    
    let sampleLabel = "Sample Rate:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let bufferLabel = "Buffer Size:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let ioLabel = "- I/O Latency:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let deviceLabel = "- Device Latency:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let safetyLabel = "- Safety Offset:".padding(toLength: 20, withPad: " ", startingAt: 0)
    let totalLabel = "Total:".padding(toLength: 20, withPad: " ", startingAt: 0)
    
    var output = "Audio Hardware Latency Estimate:\n\n"
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
