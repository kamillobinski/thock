import Foundation
import AppKit

/**
 Monitors the state of the Apple Music, Spotify, and VLC applications to determine if music is currently playing.
 
 This class uses an `osascript` subprocess to query the `player state` of running music apps.
 This approach was chosen as a workaround for the complexities and silent failures associated with using `ScriptingBridge`,
 especially in unsigned applications that may not correctly trigger system permissions prompts for Automation.
 
 Before invoking `osascript`, the monitor checks `NSWorkspace.shared.runningApplications` to determine which
 music apps are actually running. This avoids relying on AppleScript's `application "X" is running` construct,
 which can unexpectedly launch apps on some macOS versions. If no monitored apps are running, the `osascript`
 call is skipped entirely.
 
 The monitor polls at a set interval (`3.0` seconds) to update the `isMusicAppPlaying` property.
 */
class AudioMonitor {
    /// A shared singleton instance of the `AudioMonitor`.
    static let shared = AudioMonitor()
    
    /// A boolean property indicating whether music is currently playing in the Music app.
    private(set) var isMusicAppPlaying: Bool = false
    
    /// The timer responsible for periodically polling the Music app's player state.
    private var timer: Timer?
    
    /// Bundle identifiers for monitored music apps.
    private let monitoredApps: [(bundleId: String, scriptBlock: String)] = [
        ("com.apple.Music", "tell application \"Music\" to if player state is playing then set isPlaying to true"),
        ("com.spotify.client", "tell application \"Spotify\" to if player state is playing then set isPlaying to true"),
        ("org.videolan.vlc", "tell application \"VLC\" to if playing then set isPlaying to true")
    ]
    
    private init() {
        // Listen for setting changes to start/stop polling dynamically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsDidChange,
            object: nil
        )
        // Start polling on init if enabled
        if SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
            startPolling()
            // Do the first check right after init completes
            DispatchQueue.main.async {
                self.isMusicAppPlaying = self.queryAllAudioApps()
            }
        }
    }
    
    /// Starts the timer to periodically poll the Music app's player state.
    private func startPolling() {
        stopPolling() // Clearing any prev timer
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            self.isMusicAppPlaying = self.queryAllAudioApps()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    /// Stops the polling timer and resets the player state.
    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isMusicAppPlaying = false
    }
    
    /// Queries all music apps player state using an `osascript` subprocess.
    ///
    /// Uses `NSWorkspace.shared.runningApplications` to determine which music apps are running
    /// before building the AppleScript. This prevents AppleScript from launching apps that are not running.
    /// If no monitored apps are running, the osascript call is skipped entirely.
    ///
    /// - Returns: `true` if music is playing, `false` otherwise.
    private func queryAllAudioApps() -> Bool {
        let runningBundleIds = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier }
        )
        
        // Build script blocks only for apps that are currently running
        let activeBlocks = monitoredApps
            .filter { runningBundleIds.contains($0.bundleId) }
            .map { $0.scriptBlock }
        
        // If no monitored apps are running, skip osascript entirely
        if activeBlocks.isEmpty {
            return false
        }
        
        let script = (["set isPlaying to false"] + activeBlocks + ["return isPlaying"])
            .joined(separator: "\n")
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "false"
        return output.lowercased() == "true"
    }
    
    /// Handles setting changes by starting or stopping the polling timer.
    @objc private func handleSettingsChanged() {
        let shouldPoll = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
        shouldPoll ? startPolling() : stopPolling()
    }
}
