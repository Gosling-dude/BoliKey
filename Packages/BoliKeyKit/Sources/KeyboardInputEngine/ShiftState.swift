import Foundation

public enum ShiftState: Equatable, Sendable {
    case off, once, locked

    public var isUppercase: Bool { self != .off }

    /// A tap of the shift key. Two taps within the window lock it.
    public func tapped(isDoubleTap: Bool) -> ShiftState {
        switch self {
        case .off: return isDoubleTap ? .locked : .once
        case .once: return isDoubleTap ? .locked : .off
        case .locked: return .off
        }
    }

    public var afterCharacter: ShiftState { self == .locked ? .locked : .off }
}

public enum AutoCapitalizationMode: Equatable, Sendable {
    case none, words, sentences, allCharacters
}

public enum AutoCapitalization {
    /// Whether the next letter should be uppercase, given the text before the cursor.
    public static func shouldCapitalize(before text: String?, mode: AutoCapitalizationMode) -> Bool {
        switch mode {
        case .none: return false
        case .allCharacters: return true
        case .words:
            guard let last = text?.last else { return true }
            return last.isWhitespace
        case .sentences:
            guard let text, !text.isEmpty else { return true }
            guard let last = text.last else { return true }
            if last == "\n" { return true }
            guard last == " " else { return false }
            let trimmed = text.reversed().drop { $0 == " " }
            guard let mark = trimmed.first else { return true }
            return ".!?।\n".contains(mark)
        }
    }
}
