import Foundation

public struct Token: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case word, number, punctuation, emoji, symbolic }
    public let text: String
    public let kind: Kind
    public init(text: String, kind: Kind) { self.text = text; self.kind = kind }
    public var lowered: String { text.lowercased() }
}

/// Splits text into words, numbers, punctuation and URL-like chunks without losing them.
public enum Tokenizer {
    public static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        for chunk in text.split(whereSeparator: { $0.isWhitespace }) {
            tokens.append(contentsOf: split(String(chunk)))
        }
        return tokens
    }

    private static func split(_ chunk: String) -> [Token] {
        if isSymbolic(chunk) { return [Token(text: chunk, kind: .symbolic)] }
        var out: [Token] = []
        var current = ""
        func flush() {
            guard !current.isEmpty else { return }
            let isNumber = current.allSatisfy { $0.isNumber || $0 == ":" || $0 == "." }
            out.append(Token(text: current, kind: isNumber ? .number : .word))
            current = ""
        }
        for ch in chunk {
            if isWordCharacter(ch) {
                current.append(ch)
            } else if (ch == "'" || ch == "’"), !current.isEmpty {
                current.append("'")
            } else if (ch == ":" || ch == "."), current.last?.isNumber == true {
                current.append(ch)
            } else {
                flush()
                out.append(Token(text: String(ch), kind: ch.isEmojiLike ? .emoji : .punctuation))
            }
        }
        flush()
        return out
    }

    /// Letters, digits, and the combining marks Devanagari depends on.
    public static func isWordCharacter(_ ch: Character) -> Bool {
        if ch.isLetter || ch.isNumber { return true }
        return ch.unicodeScalars.contains { $0.properties.generalCategory == .nonspacingMark || $0.properties.generalCategory == .spacingMark }
    }

    /// URLs, emails, handles and hashtags are never language and never corrected.
    public static func isSymbolic(_ chunk: String) -> Bool {
        let lower = chunk.lowercased()
        if lower.hasPrefix("http") || lower.hasPrefix("www.") { return true }
        if chunk.hasPrefix("@") || chunk.hasPrefix("#") { return chunk.count > 1 }
        if let at = chunk.firstIndex(of: "@"), chunk[at...].contains(".") { return true }
        if chunk.contains("."), let tld = chunk.split(separator: ".").last,
           ["com", "in", "org", "net", "io", "co", "ai", "app"].contains(tld.lowercased()), chunk.first?.isLetter == true,
           chunk.split(separator: ".").count >= 2 { return true }
        return false
    }

    /// The word being typed at the end of `text`, or "" when the cursor follows a separator.
    public static func trailingWord(in text: String) -> String {
        var scalars: [Character] = []
        for ch in text.reversed() {
            if isWordCharacter(ch) || ((ch == "'" || ch == "’") && !scalars.isEmpty) {
                scalars.append(ch)
            } else {
                break
            }
        }
        return String(scalars.reversed())
    }

    /// Text following the last sentence-ending mark.
    public static func currentSentence(in text: String) -> String {
        let stops: Set<Character> = [".", "!", "?", "\n", "।"]
        var start = text.endIndex
        var idx = text.endIndex
        while idx > text.startIndex {
            let prev = text.index(before: idx)
            if stops.contains(text[prev]) {
                // A trailing mark belongs to the sentence that it closes.
                if text[idx...].trimmingCharacters(in: .whitespaces).isEmpty {
                    idx = prev
                    continue
                }
                break
            }
            idx = prev
            start = idx
        }
        return String(text[start...]).trimmingCharacters(in: .whitespaces)
    }
}

extension Character {
    var isEmojiLike: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }
    }
}
