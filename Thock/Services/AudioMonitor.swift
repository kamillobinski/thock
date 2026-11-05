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
 
 The subprocess is blocking, so polling runs on a private queue rather than the main run loop: the main run
 loop also hosts the CGEvent taps and the audio queue render callback, and blocking it there delayed both.
 `isMusicAppPlaying` is still only ever read and written on the main thread.

 The monitor polls at a set interval (`3.0` seconds) to update the `isMusicAppPlaying` property.
 */
class AudioMonitor {
    /// A shared singleton instance of the `AudioMonitor`.
    static let shared = AudioMonitor()
    
    /// A boolean property indicating whether music is currently playing in the Music app.
    /// Only written on the main thread.
    private(set) var isMusicAppPlaying: Bool = false
    
    /// The timer responsible for periodically polling the Music app's player state.
    private var timer: DispatchSourceTimer?
    // Main-thread generation: a cancelled query must not publish into a later session.
    private var pollingGeneration: UInt64 = 0

    /// Serial queue the blocking `osascript` query runs on.
    private let pollingQueue = DispatchQueue(
        label: "dev.kamillobinski.Thock.audio-monitor",
        qos: .utility
    )
    
    /// Bundle identifiers for monitored music apps.
    private let monitoredApps: [(bundleId: String, scriptBlock: String)] = [
        ("com.apple.Music", "tell application \"Music\" to if player state is playing then set isPlaying to true"),
        ("com.spotify.client", "tell application \"Spotify\" to if player state is playing then set isPlaying to true"),
        ("org.videolan.vlc", "tell application \"VLC\" to if playing then set isPlaying to true")
    ]
    
    private init() {
        // Listen for setting changes to start/stop polling dynamically
        NotificationCenter.default.addObserver(
            forName: .settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSettingsChanged()
        }

        // Start polling on init if enabled. The timer's first fire is immediate,
        // so this doubles as the initial check.
        if SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
            startPolling()
        }
    }
    
    /// Starts the timer to periodically poll the Music app's player state.
    private func startPolling() {
        stopPolling() // Clearing any prev timer
        let generation = pollingGeneration

        let timer = DispatchSource.makeTimerSource(queue: pollingQueue)
        timer.schedule(deadline: .now(), repeating: 3.0, leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }

            // Blocks until osascript exits, so it must stay off the main run loop.
            let isPlaying = self.queryAllAudioApps()

            // Publish on main: the event tap callbacks read this on the main thread.
            DispatchQueue.main.async {
                guard self.timer != nil, self.pollingGeneration == generation else { return }
                self.isMusicAppPlaying = isPlaying
            }
        }
        timer.resume()
        self.timer = timer
    }
    
    /// Stops the polling timer and resets the player state.
    func stopPolling() {
        pollingGeneration &+= 1
        timer?.cancel()
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
    private func handleSettingsChanged() {
        let shouldPoll = SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled()
        shouldPoll ? startPolling() : stopPolling()
    }
}
