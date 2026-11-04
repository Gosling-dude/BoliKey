import Foundation
import LanguageCore

/// Understands how Hindi is really written in Roman script.
public final class HinglishEngine {
    private let lexicon: Lexicon
    private lazy var phoneticIndex: [String: [String]] = buildPhoneticIndex()

    /// Common spellings that normalisation leaves alone because nobody considers them
    /// wrong. They stay recognised variants for prediction.
    private static let settledSpellings: Set<String> = ["hu", "hai", "ho", "toh", "to", "yeh", "ye", "wo", "woh", "aur"]

    public init(lexicon: Lexicon = .shared) {
        self.lexicon = lexicon
    }

    public func isHindi(_ word: String) -> Bool {
        lexicon.entry(word)?.flags.contains(.hinglish) == true
    }

    /// The conventional spelling for a Hindi word, or nil when it is already conventional.
    public func conventionalSpelling(of word: String) -> String? {
        let lower = word.lowercased()
        guard !Self.settledSpellings.contains(lower),
              let entry = lexicon.entry(lower), entry.flags.contains(.hinglish),
              let canonical = entry.canonical, canonical != lower else { return nil }
        return canonical
    }

    /// "bhaaaai" to "bhai", "yaarrrr" to "yaar". Elongation is expression, not a typo.
    public func collapseElongation(_ word: String) -> String? {
        let lower = word.lowercased()
        var runs: [(Character, Int)] = []
        for ch in lower {
            if let last = runs.last, last.0 == ch {
                runs[runs.count - 1].1 += 1
            } else {
                runs.append((ch, 1))
            }
        }
        guard runs.contains(where: { $0.1 >= 3 }) else { return nil }
        // Try every run at two letters, then each at one, keeping the first real word.
        let twice = String(runs.flatMap { Array(repeating: $0.0, count: min($0.1, 2)) })
        if lexicon.isKnown(twice) { return twice }
        let once = String(runs.flatMap { [$0.0] as [Character] })
        if lexicon.isKnown(once) { return once }
        for i in runs.indices where runs[i].1 >= 2 {
            var trial = runs.map { (c: $0.0, n: min($0.1, 2)) }
            trial[i].n = 1
            let word = String(trial.flatMap { Array(repeating: $0.c, count: $0.n) })
            if lexicon.isKnown(word) { return word }
        }
        return nil
    }

    /// A loose phonetic key: Hindi spellings that sound alike share one.
    /// nahi, nhi and nahin all reduce to the same key.
    public static func phoneticKey(_ word: String) -> String {
        var s = word.lowercased()
        for (a, b) in [("ph", "f"), ("z", "j"), ("v", "w"), ("q", "k"), ("ck", "k"), ("sh", "s"), ("chh", "c"), ("ch", "c"), ("kh", "k"), ("gh", "g"), ("dh", "d"), ("th", "t"), ("bh", "b")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        var out = ""
        for (i, ch) in s.enumerated() {
            let isVowel = "aeiouy".contains(ch)
            if isVowel, i > 0 { continue }
            if ch == "h", i > 0 { continue }
            if ch == "n", i == s.count - 1, out.count > 1 { continue }
            if out.last == ch { continue }
            out.append(ch)
        }
        return out
    }

    private func buildPhoneticIndex() -> [String: [String]] {
        var index: [String: [String]] = [:]
        for (word, entry) in lexicon.entries where entry.flags.contains(.hinglish) && entry.canonical == nil && word.count >= 3 {
            index[Self.phoneticKey(word), default: []].append(word)
        }
        for key in index.keys {
            index[key]?.sort { (lexicon.entries[$0]?.hindiCount ?? 0) > (lexicon.entries[$1]?.hindiCount ?? 0) }
        }
        return index
    }

    /// Conventional Hindi words that sound like `word`, most common first.
    public func phoneticMatches(_ word: String) -> [String] {
        guard word.count >= 3 else { return [] }
        return phoneticIndex[Self.phoneticKey(word)] ?? []
    }

    /// Whether an unknown word reads as Roman-script Hindi, from character statistics.
    public func readsAsHindi(_ word: String) -> Bool {
        let logs = lexicon.charGramLogs(word.lowercased())
        return logs.hi - logs.en > 0.6
    }

    private lazy var improvementRules: [(from: [String], to: [String])] = Self.loadImprovements()

    private static func loadImprovements() -> [(from: [String], to: [String])] {
        ImprovementData.rows.map { row in
            (row.0.split(separator: " ").map(String.init), row.1.split(separator: " ").map(String.init))
        }
    }

    /// Applies the first matching improvement rule to a normalised sentence.
    public func improved(_ normalised: String) -> String? {
        let words = normalised.split(separator: " ").map(String.init)
        let lowered = words.map { $0.lowercased() }
        for rule in improvementRules where rule.from.count <= lowered.count {
            for start in 0...(lowered.count - rule.from.count) where Array(lowered[start..<(start + rule.from.count)]) == rule.from {
                let out = Array(words[..<start]) + rule.to + Array(words[(start + rule.from.count)...])
                return out.joined(separator: " ")
            }
        }
        return nil
    }
}
