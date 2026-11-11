// SoundpackCycle: picks the next or previous soundpack for the
// "next/previous keyboard soundpack" global shortcuts.
//
// Called by GlobalShortcutManager. Pure functions only (no file system, no
// singletons) so ThockTests can cover the ordering.
//
// The order must match the menu bar list in MenuBarController.addSoundpackSection
// (brand, then author, then name), so a shortcut press moves to the item the user
// sees next in the menu. If you change the menu sort, change menuOrder too.

import Foundation

enum SoundpackCycle {
    enum Direction {
        case next
        case previous
    }

    /// Sorts soundpacks the same way the menu bar shows them.
    static func menuOrder(_ soundpacks: [Soundpack]) -> [Soundpack] {
        soundpacks.sorted {
            ($0.brand, $0.author, $0.name) < ($1.brand, $1.author, $1.name)
        }
    }

    /// Returns the soundpack after (or before) `current` in menu order, wrapping
    /// at both ends. Returns the first pack when `current` is nil or no longer
    /// installed. Returns nil when there is nothing to switch to.
    static func step(from current: Soundpack?, in soundpacks: [Soundpack], direction: Direction) -> Soundpack? {
        let ordered = menuOrder(soundpacks)
        guard !ordered.isEmpty else { return nil }

        guard let current, let index = ordered.firstIndex(of: current) else {
            return ordered.first
        }

        let offset = direction == .next ? 1 : -1
        let nextIndex = (index + offset + ordered.count) % ordered.count
        return ordered[nextIndex]
    }
}
