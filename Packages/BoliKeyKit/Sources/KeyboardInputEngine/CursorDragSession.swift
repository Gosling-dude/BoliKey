import Foundation

/// Turns space-bar drag steps into cursor offsets, one whole character per step.
///
/// `adjustTextPosition(byCharacterOffset:)` counts UTF-16 code units, so an emoji or a Devanagari
/// cluster takes more than one unit. Moving by one unit at a time can leave the cursor inside it.
///
/// The text around the cursor is captured once, when the drag starts. The proxy updates its context
/// asynchronously, so reading it again after every step would give positions that are out of date.
/// The text itself cannot change during a drag, so the captured copy stays correct.
public struct CursorDragSession: Equatable, Sendable {
    private var characters: [Character]
    private var index: Int

    public init(before: String, after: String) {
        characters = Array(before) + Array(after)
        index = before.count
    }

    /// The offset that moves the cursor up to `steps` characters, negative to the left, and how many
    /// characters that is. It stops at the edges of the captured text.
    public mutating func offset(forSteps steps: Int) -> (offset: Int, moved: Int) {
        var offset = 0
        var moved = 0
        if steps < 0 {
            while moved > steps, index > 0 {
                index -= 1
                offset -= characters[index].utf16.count
                moved -= 1
            }
        } else {
            while moved < steps, index < characters.count {
                offset += characters[index].utf16.count
                index += 1
                moved += 1
            }
        }
        return (offset, moved)
    }

    /// Called at an edge of the captured text. Some apps only share part of a long text, and share
    /// more once the cursor gets near its edge. Returns whether the newly shared text was taken up.
    /// The same text split at a different point is only a context that has not caught up yet.
    public mutating func extend(before: String, after: String) -> Bool {
        let shared = Array(before) + Array(after)
        guard shared != characters else { return false }
        characters = shared
        index = before.count
        return true
    }
}
