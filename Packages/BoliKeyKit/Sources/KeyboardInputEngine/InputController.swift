import Foundation

/// What the input logic needs from the text field. UITextDocumentProxy provides this
/// in the keyboard, and a plain string provides it in tests and the in-app preview.
public protocol TextProxying: AnyObject {
    var contextBeforeCursor: String? { get }
    var contextAfterCursor: String? { get }
    func insert(_ text: String)
    func deleteBackward()
    func moveCursor(by offset: Int)
}

/// Decisions that need language knowledge, supplied by the app layer.
public protocol WordBoundaryDelegate: AnyObject {
    /// What to replace a just-finished word with, or nil to keep it. Must be fast.
    func correction(for word: String, context: String) -> String?
    func didUndoCorrection(typed: String, corrected: String)
}

public struct InputConfiguration: Equatable, Sendable {
    public var autoCapitalizeEnabled = true
    public var autoCapitalizationMode: AutoCapitalizationMode = .sentences
    public var doubleSpacePeriodEnabled = true
    public var autoCorrectAllowed = true
    /// A full stop typed after Hindi, or the double-space shortcut there, writes a danda: ।
    public var dandaAfterDevanagari = false
    public init() {}
}

/// All typing behaviour that is independent of the UI: characters, shift, backspace,
/// space, return, autocorrect-on-boundary with undo, and suggestion acceptance.
public final class InputController {
    public weak var delegate: WordBoundaryDelegate?
    public var proxy: TextProxying
    public var configuration = InputConfiguration()
    public private(set) var shift: ShiftState = .off
    public var onStateChange: (() -> Void)?

    private struct AppliedCorrection {
        let typed: String
        let corrected: String
        let separator: String
    }
    private var lastCorrection: AppliedCorrection?
    private var lastSpaceTime: TimeInterval = 0
    private var lastShiftTap: TimeInterval = 0
    /// A space the keyboard added itself after a suggestion. Punctuation replaces it.
    private var autoSpaceAdded = false
    private let doubleTapWindow: TimeInterval = 0.35
    public var now: () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }

    public init(proxy: TextProxying) {
        self.proxy = proxy
    }

    public func syncAutoCapitalization() {
        guard shift != .locked else { return }
        let wanted = configuration.autoCapitalizeEnabled
            && AutoCapitalization.shouldCapitalize(before: proxy.contextBeforeCursor, mode: configuration.autoCapitalizationMode)
        let next: ShiftState = wanted ? .once : .off
        if next != shift {
            shift = next
            onStateChange?()
        }
    }

    public func tapShift() {
        let t = now()
        let isDouble = t - lastShiftTap < doubleTapWindow
        lastShiftTap = t
        shift = shift.tapped(isDoubleTap: isDouble)
        onStateChange?()
    }

    public func insertCharacter(_ raw: String, respectingShift: Bool = true) {
        var text = raw
        if respectingShift, shift.isUppercase { text = raw.uppercased() }
        if autoSpaceAdded, let first = raw.first, ".,?!:;।".contains(first), proxy.contextBeforeCursor?.hasSuffix(" ") == true {
            proxy.deleteBackward()
        }
        autoSpaceAdded = false
        if let first = raw.first, !isWordCharacter(first) {
            applyCorrectionIfNeeded(separator: raw)
        }
        lastCorrection = (raw.first.map { isWordCharacter($0) } ?? false) ? nil : lastCorrection
        // After the word before it became Devanagari, so that "namaste." ends in a danda.
        if raw == ".", configuration.dandaAfterDevanagari, let last = proxy.contextBeforeCursor?.last, Self.isDevanagari(last) {
            text = "।"
            if let c = lastCorrection { lastCorrection = AppliedCorrection(typed: c.typed, corrected: c.corrected, separator: text) }
        }
        proxy.insert(text)
        lastSpaceTime = 0
        let after = shift.afterCharacter
        if after != shift {
            shift = after
            onStateChange?()
        }
        syncAutoCapitalization()
    }

    public func insertLiteral(_ text: String) {
        autoSpaceAdded = false
        lastCorrection = nil
        proxy.insert(text)
        syncAutoCapitalization()
    }

    public func tapSpace() {
        let t = now()
        let before = proxy.contextBeforeCursor ?? ""
        if configuration.doubleSpacePeriodEnabled, t - lastSpaceTime < 0.4, before.hasSuffix(" "),
           let mark = before.dropLast().last, mark.isLetter || mark.isNumber || isMarkCharacter(mark) {
            proxy.deleteBackward()
            proxy.insert(configuration.dandaAfterDevanagari && Self.isDevanagari(mark) ? "। " : ". ")
            lastSpaceTime = 0
            autoSpaceAdded = false
            syncAutoCapitalization()
            return
        }
        applyCorrectionIfNeeded(separator: " ")
        proxy.insert(" ")
        autoSpaceAdded = false
        lastSpaceTime = t
        syncAutoCapitalization()
    }

    public func tapReturn() {
        applyCorrectionIfNeeded(separator: "\n")
        lastCorrection = nil
        autoSpaceAdded = false
        proxy.insert("\n")
        syncAutoCapitalization()
    }

    public func tapBackspace() {
        autoSpaceAdded = false
        // The first backspace after an autocorrection restores what the user typed.
        if let correction = lastCorrection, let before = proxy.contextBeforeCursor,
           before.hasSuffix(correction.corrected + correction.separator) {
            for _ in 0..<correction.separator.count { proxy.deleteBackward() }
            deleteTrailing(correction.corrected)
            proxy.insert(correction.typed)
            delegate?.didUndoCorrection(typed: correction.typed, corrected: correction.corrected)
            lastCorrection = nil
            syncAutoCapitalization()
            return
        }
        lastCorrection = nil
        proxy.deleteBackward()
        lastSpaceTime = 0
        syncAutoCapitalization()
    }

    /// Deletes back to the start of the previous word. Used when backspace is held for a while.
    public func deleteWordBackward() {
        lastCorrection = nil
        guard let before = proxy.contextBeforeCursor, !before.isEmpty else {
            proxy.deleteBackward()
            return
        }
        var chars = Array(before)
        var count = 0
        while let last = chars.last, last.isWhitespace || last.isPunctuation {
            chars.removeLast()
            count += 1
        }
        while let last = chars.last, !last.isWhitespace, !last.isPunctuation {
            chars.removeLast()
            count += 1
        }
        for _ in 0..<max(count, 1) { proxy.deleteBackward() }
        syncAutoCapitalization()
    }

    /// Replaces `replacing`, the end of the text, with `text`.
    public func accept(replacing: String, with text: String, addSpace: Bool) {
        lastCorrection = nil
        if !replacing.isEmpty { deleteTrailing(replacing) }
        proxy.insert(text)
        if addSpace, proxy.contextAfterCursor?.first?.isWhitespace != true {
            proxy.insert(" ")
            autoSpaceAdded = true
        }
        lastSpaceTime = 0
        syncAutoCapitalization()
    }

    /// Removes `word` from the end of the text. Cluster boundaries differ across hosts and
    /// scripts, so this deletes by scalar count and checks with the proxy along the way.
    private func deleteTrailing(_ word: String) {
        guard let before = proxy.contextBeforeCursor, before.hasSuffix(word) else {
            for _ in 0..<word.count { proxy.deleteBackward() }
            return
        }
        let target = before.dropLast(word.count)
        var guardCount = word.unicodeScalars.count + 1
        while guardCount > 0 {
            guard let now = proxy.contextBeforeCursor else { return }
            if now.count <= target.count && now == target { return }
            if !now.hasPrefix(target) { return }
            proxy.deleteBackward()
            guardCount -= 1
        }
    }

    private func applyCorrectionIfNeeded(separator: String) {
        lastCorrection = nil
        guard configuration.autoCorrectAllowed, let delegate, let before = proxy.contextBeforeCursor else { return }
        let word = Self.trailingWord(in: before)
        guard !word.isEmpty else { return }
        let context = String(before.dropLast(word.count))
        guard let corrected = delegate.correction(for: word, context: context), corrected != word else { return }
        deleteTrailing(word)
        proxy.insert(corrected)
        lastCorrection = AppliedCorrection(typed: word, corrected: corrected, separator: separator)
    }

    private func isWordCharacter(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || isMarkCharacter(ch) || ch == "'"
    }

    private func isMarkCharacter(_ ch: Character) -> Bool {
        ch.unicodeScalars.contains { $0.properties.generalCategory == .nonspacingMark || $0.properties.generalCategory == .spacingMark }
    }

    static func isDevanagari(_ ch: Character) -> Bool {
        ch.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) }
    }

    static func trailingWord(in text: String) -> String {
        var out: [Character] = []
        for ch in text.reversed() {
            let isMark = ch.unicodeScalars.contains { $0.properties.generalCategory == .nonspacingMark || $0.properties.generalCategory == .spacingMark }
            if ch.isLetter || ch.isNumber || isMark || (ch == "'" && !out.isEmpty) {
                out.append(ch)
            } else {
                break
            }
        }
        return String(out.reversed())
    }
}

/// A plain text buffer implementing the proxy, used by tests and the in-app preview.
public final class StringTextProxy: TextProxying {
    public var text: String
    public var onChange: ((String) -> Void)?
    public init(_ text: String = "") { self.text = text }
    public var contextBeforeCursor: String? { text }
    public var contextAfterCursor: String? { nil }
    public func insert(_ s: String) {
        text += s
        onChange?(text)
    }
    public func deleteBackward() {
        if !text.isEmpty { text.removeLast() }
        onChange?(text)
    }
    public func moveCursor(by offset: Int) {}
}
