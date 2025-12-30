import Foundation
import AppKit

enum CustomSoundpackHelper {
    /// Opens the custom soundpack directory in Finder, creating it if it doesn't exist
    static func openCustomSoundpackDirectory() {
        let directory = getCustomSoundpackDirectory()
        
        // Create it if none
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Open
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: directory.path)
    }
    
    /// Returns the URL for the custom soundpack directory
    static func getCustomSoundpackDirectory() -> URL {
        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Thock/CustomSounds", isDirectory: true)
    }
}
