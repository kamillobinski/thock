
import Foundation

/**
 Monitors the state of the Apple Music and Spotify applications to determine if music is currently playing.
 
 This class uses an `osascript` subprocess to query the `player state` of the Music.app and Spotify.app.
 This approach was chosen as a workaround for the complexities and silent failures associated with using `ScriptingBridge`,
 especially in unsigned applications that may not correctly trigger system permissions prompts for Automation.
 
 The monitor polls the Music ans Spotify apps at a set interval (`3.0` seconds) to update the `isMusicAppPlaying` property.
 */
class AudioMonitor {
    /// A shared singleton instance of the `AudioMonitor`.
    static let shared = AudioMonitor()
    
    /// A boolean property indicating whether music is currently playing in the Music app.
    private(set) var isMusicAppPlaying: Bool = false
    
    /// The timer responsible for periodically polling the Music app's player state.
    private var timer: Timer?
    
    private init() {
        // Listen for setting changes to start/stop polling dynamically
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsDidChange,
            object: nil
        )
        // Start polling on init
        if SettingsEngine.shared.isAutoMuteOnMusicPlaybackEnabled() {
            startPolling()
        }
        // Do the first check right after init completes
        DispatchQueue.main.async {
            self.isMusicAppPlaying = self.queryAllAudioApps()
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
    /// - Returns: `true` if music is playing, `false` otherwise.
    private func queryAllAudioApps() -> Bool {
        let script = """
        set isPlaying to false
        if application "Music" is running then
            tell application "Music" to if player state is playing then set isPlaying to true
        end if
        if application "Spotify" is running then
            tell application "Spotify" to if player state is playing then set isPlaying to true
        end if
        if application "VLC" is running then
            tell application "VLC" to if playing then set isPlaying to true
        end if
        return isPlaying
        """
        
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
