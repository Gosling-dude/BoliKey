import Foundation
import LanguageCore

/// Converts between Roman-script Hindi and Devanagari.
/// Known words use the authored lexicon. Everything else goes through a phonetic ruleset,
/// which is approximate for unknown words and documented as such.
public struct Transliterator {
    private let lexicon: Lexicon

    public init(lexicon: Lexicon = .shared) {
        self.lexicon = lexicon
    }

    public func toDevanagari(sentence: String) -> String {
        var out = ""
        var word = ""
        func flush() {
            guard !word.isEmpty else { return }
            out += toDevanagari(word: word)
            word = ""
        }
        for ch in sentence {
            if ch.isASCII, ch.isLetter {
                word.append(ch)
            } else {
                flush()
                out.append(ch == "." ? "।" : ch)
            }
        }
        flush()
        return out
    }

    public func toDevanagari(word: String) -> String {
        let lower = word.lowercased()
        if let entry = lexicon.entry(lower), entry.flags.contains(.hinglish), let deva = entry.devanagari { return deva }
        // English words keep their Latin spelling inside a Hindi sentence unless they are loanwords we know.
        if let entry = lexicon.entry(lower), entry.flags.contains(.english), entry.hindiCount == 0 { return word }
        return Self.ruleBased(lower)
    }

    public func toRoman(word: String) -> String? {
        lexicon.roman(forDevanagari: word)
    }

    public func toRoman(sentence: String) -> String {
        Tokenizer.tokenize(sentence).map { token in
            token.kind == .word ? (toRoman(word: token.text) ?? token.text) : token.text
        }.joined(separator: " ")
    }

    private static let consonants: [(String, String)] = [
        ("chh", "छ"), ("kh", "ख"), ("gh", "घ"), ("ch", "च"), ("jh", "झ"), ("th", "थ"), ("dh", "ध"), ("ph", "फ"), ("bh", "भ"), ("sh", "श"),
        ("k", "क"), ("g", "ग"), ("j", "ज"), ("t", "त"), ("d", "द"), ("n", "न"), ("p", "प"), ("f", "फ़"), ("b", "ब"), ("m", "म"),
        ("y", "य"), ("r", "र"), ("l", "ल"), ("v", "व"), ("w", "व"), ("s", "स"), ("h", "ह"), ("z", "ज़"), ("q", "क़"), ("x", "क्स"), ("c", "क"),
    ]
    private static let vowels: [(String, independent: String, matra: String)] = [
        ("aa", "आ", "ा"), ("ai", "ऐ", "ै"), ("au", "औ", "ौ"), ("ee", "ई", "ी"), ("oo", "ऊ", "ू"), ("ou", "औ", "ौ"),
        ("a", "अ", ""), ("i", "इ", "ि"), ("u", "उ", "ु"), ("e", "ए", "े"), ("o", "ओ", "ो"),
    ]

    /// Longest-match phonetic conversion with an implicit schwa between consonants.
    public static func ruleBased(_ word: String) -> String {
        var out = ""
        var rest = Substring(word)
        var previousWasConsonant = false
        while !rest.isEmpty {
            if let v = vowels.first(where: { rest.hasPrefix($0.0) }) {
                out += previousWasConsonant ? v.matra : v.independent
                rest = rest.dropFirst(v.0.count)
                previousWasConsonant = false
                continue
            }
            if let c = consonants.first(where: { rest.hasPrefix($0.0) }) {
                // A nasal before another consonant is written as an anusvara.
                if c.0 == "n", !previousWasConsonant, out.isEmpty == false,
                   let next = rest.dropFirst().first, !"aeiou".contains(next) {
                    out += "ं"
                    rest = rest.dropFirst()
                    continue
                }
                if previousWasConsonant { out += "्" }
                out += c.1
                rest = rest.dropFirst(c.0.count)
                previousWasConsonant = true
                continue
            }
            out.append(rest.removeFirst())
            previousWasConsonant = false
        }
        return out
    }
}
