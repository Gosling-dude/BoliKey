import Foundation
import LanguageCore

/// Hindi typed in English letters, turned into Devanagari: `namaste` into `नमस्ते`.
///
/// Roman spelling leaves a lot open. `t` may be त or ट, a final `a` is usually ा, and `karna` is
/// करना while `garmi` is गर्मी, though both have two consonants together. So each word is spelled
/// several ways, and the spellings real Hindi text uses win:
///
/// 1. The authored lexicon: `kya` is क्या.
/// 2. Spellings in the Devanagari vocabulary, most frequent first: `bharat` finds भारत.
/// 3. The most regular spelling, for a word neither knows, such as a name.
///
/// A common English word with no Hindi spelling in either list, such as `ok` or `please`, is left in
/// English, and so is a word with no vowels, such as `rs` or `km`, unless the lexicon knows it.
public struct PhoneticHindi {
    private let lexicon: Lexicon

    public init(lexicon: Lexicon = .shared) {
        self.lexicon = lexicon
    }

    /// A word this can convert: English letters only.
    public static func isRoman(_ word: String) -> Bool {
        !word.isEmpty && word.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("A"..."Z").contains($0) }
    }

    /// English words at least this common in the English list stay English. Indian names appear
    /// in it too, from film subtitles, but far less often: rahul, priya and vijay under 4,000.
    static let commonEnglishCount: Int32 = 10_000

    /// What `roman` becomes at the end of the word, or nil to leave it in English letters.
    public func conversion(of roman: String) -> String? {
        let word = roman.lowercased()
        guard Self.isRoman(word) else { return nil }
        if let authored = authored(word) { return authored }
        // Without a vowel it is an abbreviation: rs, km, tv.
        guard word.contains(where: { "aeiou".contains($0) }) else { return nil }
        let ranked = rankedSpellings(of: word)
        let isCommonEnglish = lexicon.entry(word).map { $0.flags.contains(.english) && $0.englishCount >= Self.commonEnglishCount } ?? false
        // A common English word turns Hindi only as its plainest reading: is to इस, but never bus to बुश.
        if let known = ranked.first(where: { $0.known && (!isCommonEnglish || $0.cost == 0) }) { return known.text }
        // Otherwise it stays English. A word nobody knows is probably Hindi, often a name.
        return isCommonEnglish ? nil : ranked.first?.text
    }

    /// Devanagari spellings of `roman`, best first.
    public func candidates(for roman: String, limit: Int = 4) -> [String] {
        let word = roman.lowercased()
        guard Self.isRoman(word) else { return [] }
        var out: [String] = []
        func add(_ s: String) { if !out.contains(s) { out.append(s) } }
        if let authored = authored(word) { add(authored) }
        let ranked = rankedSpellings(of: word)
        for spelling in ranked where spelling.known { add(spelling.text) }
        // With nothing known, the two most regular spellings, so there is always a choice.
        if out.isEmpty {
            for spelling in ranked.prefix(2) { add(spelling.text) }
        }
        return Array(out.prefix(limit))
    }

    /// Devanagari for Hindi words that start with `prefix`, likeliest first: `namas` offers `नमस्ते`.
    public func completions(of prefix: String, limit: Int = 2) -> [String] {
        let lower = prefix.lowercased()
        guard Self.isRoman(lower), lower.count >= 2 else { return [] }
        var out: [String] = []
        for match in lexicon.latinTrie.completions(of: lower, limit: 24) where match.word != lower {
            guard let entry = lexicon.entry(match.word), entry.flags.contains(.hinglish), !entry.flags.contains(.noSuggest),
                  let deva = entry.devanagari, !out.contains(deva) else { continue }
            out.append(deva)
            if out.count == limit { break }
        }
        return out
    }

    private func authored(_ word: String) -> String? {
        guard let entry = lexicon.entry(word), entry.flags.contains(.hinglish), let deva = entry.devanagari else { return nil }
        return deva
    }

    // MARK: Spelling it out

    struct Spelling: Equatable {
        let text: String
        /// How far it strays from the most regular reading.
        let cost: Int
        let known: Bool
        let frequency: Int32
    }

    /// Every likely spelling, known Hindi words first by frequency, then the rest by regularity.
    func rankedSpellings(of word: String) -> [Spelling] {
        let units = Self.units(of: Self.collapsingRuns(word))
        var seen = Set<String>()
        let spellings = Self.spell(units).compactMap { state -> Spelling? in
            let text = state.text.precomposedStringWithCanonicalMapping
            guard seen.insert(text).inserted else { return nil }
            let entry = lexicon.entries[text]
            let known = entry?.flags.contains(.devanagari) == true
            return Spelling(text: text, cost: state.cost, known: known, frequency: known ? entry!.hindiCount : 0)
        }
        // Among known words, a rarer one wins only if it is much closer to what was typed.
        func score(_ s: Spelling) -> Double { log(Double(s.frequency) + 1) - Double(s.cost) * 0.9 }
        return spellings.sorted { a, b in
            if a.known != b.known { return a.known }
            if a.known, score(a) != score(b) { return score(a) > score(b) }
            return a.cost < b.cost
        }
    }

    /// Elongation such as `pyaaaar` is expression. Three or more of a letter count as two.
    static func collapsingRuns(_ word: String) -> String {
        var out = ""
        var run = 0
        for ch in word {
            run = out.last == ch ? run + 1 : 1
            if run <= 2 { out.append(ch) }
        }
        return out
    }

    enum Unit: Equatable {
        case vowel(String)
        case consonant(String)
    }

    private static let consonantUnits = ["ksh", "chh", "cch", "kh", "gh", "ch", "jh", "th", "dh", "ph", "bh", "sh", "gy",
                                         "k", "g", "j", "t", "d", "n", "p", "f", "b", "m", "y", "r", "l", "v", "w", "s", "h", "z", "q", "x", "c"]
    private static let vowelUnits = ["aa", "ai", "au", "ee", "ii", "oo", "uu", "ou", "a", "i", "u", "e", "o"]

    static func units(of word: String) -> [Unit] {
        var units: [Unit] = []
        var rest = Substring(word)
        while !rest.isEmpty {
            if let v = vowelUnits.first(where: { rest.hasPrefix($0) }) {
                units.append(.vowel(v))
                rest = rest.dropFirst(v.count)
            } else if let c = consonantUnits.first(where: { rest.hasPrefix($0) }) {
                units.append(.consonant(c))
                rest = rest.dropFirst(c.count)
            } else {
                rest = rest.dropFirst()
            }
        }
        return units
    }

    // Nukta letters are written decomposed, as the vocabulary stores them.
    private static let nukta = "\u{093C}"
    private static let consonantOptions: [String: [String]] = [
        "ksh": ["क्ष"], "chh": ["छ"], "cch": ["च्छ"], "kh": ["ख", "ख" + nukta], "gh": ["घ", "ग" + nukta], "ch": ["च", "छ"],
        "jh": ["झ"], "th": ["थ", "ठ"], "dh": ["ध", "ढ", "ढ" + nukta], "ph": ["फ", "फ" + nukta], "bh": ["भ"], "sh": ["श", "ष"],
        "gy": ["ग्य", "ज्ञ"],
        "k": ["क"], "g": ["ग"], "j": ["ज", "ज" + nukta], "t": ["त", "ट"], "d": ["द", "ड", "ड" + nukta], "n": ["न", "ण"],
        "p": ["प"], "f": ["फ" + nukta, "फ"], "b": ["ब"], "m": ["म"], "y": ["य"], "r": ["र", "ड" + nukta], "l": ["ल"],
        "v": ["व"], "w": ["व"], "s": ["स", "श"], "h": ["ह"], "z": ["ज" + nukta, "ज"], "q": ["क" + nukta, "क"], "x": ["क्स"],
        "c": ["क", "च", "स"],
    ]

    /// Vowel signs after a consonant, and letters standing alone, most regular first.
    private static func vowelOptions(_ v: String, afterConsonant: Bool, final: Bool) -> [String] {
        if afterConsonant {
            switch v {
            case "a": return final ? ["ा", ""] : ["", "ा"]
            case "aa": return ["ा"]
            case "i": return final ? ["ी", "ि"] : ["ि", "ी"]
            case "ee", "ii": return ["ी"]
            case "u": return final ? ["ू", "ु"] : ["ु", "ू"]
            case "oo", "uu": return ["ू"]
            case "e": return ["े", "ै"]
            case "ai": return ["ै", "ाई", "ई"]
            case "au": return ["ौ", "ाउ"]
            case "ou": return ["ौ"]
            case "o": return ["ो", "ॉ"]
            default: return []
            }
        }
        switch v {
        case "a": return ["अ", "आ"]
        case "aa": return ["आ"]
        case "i": return ["इ", "ई"]
        case "ee", "ii": return ["ई"]
        case "u": return ["उ", "ऊ"]
        case "oo", "uu": return ["ऊ"]
        case "e": return ["ए", "ऐ"]
        case "ai": return ["ऐ", "आई"]
        case "au", "ou": return ["औ"]
        case "o": return ["ओ", "ऑ"]
        default: return []
        }
    }

    struct State {
        var text = ""
        var cost = 0
        /// The text ends in a consonant with no vowel sign yet.
        var openConsonant = false
    }

    private static let beamWidth = 64

    /// A beam search over the ways to spell each unit, cheapest first.
    static func spell(_ units: [Unit]) -> [State] {
        var beam = [State()]
        for (index, unit) in units.enumerated() {
            let isLast = index == units.count - 1
            let next = index + 1 < units.count ? units[index + 1] : nil
            var expanded: [State] = []
            for state in beam {
                switch unit {
                case .vowel(let v):
                    for (cost, sign) in vowelOptions(v, afterConsonant: state.openConsonant, final: isLast).enumerated() {
                        expanded.append(State(text: state.text + sign, cost: state.cost + cost, openConsonant: false))
                    }
                case .consonant(let c):
                    let letters = consonantOptions[c] ?? []
                    // A nasal before another consonant is usually an anusvara: rang, zindagi.
                    if (c == "n" || c == "m"), !state.openConsonant, !state.text.isEmpty, case .consonant? = next {
                        expanded.append(State(text: state.text + "ं", cost: state.cost + (c == "n" ? 0 : 1), openConsonant: false))
                        for (cost, letter) in letters.enumerated() {
                            expanded.append(State(text: state.text + letter, cost: state.cost + cost + (c == "n" ? 1 : 0), openConsonant: true))
                        }
                        continue
                    }
                    // A final nasal after a vowel may only nasalise it: main, hain, kahan.
                    if c == "n", isLast, !state.openConsonant, !state.text.isEmpty {
                        expanded.append(State(text: state.text + "न", cost: state.cost, openConsonant: true))
                        expanded.append(State(text: state.text + "ं", cost: state.cost + 1, openConsonant: false))
                        expanded.append(State(text: state.text + "ँ", cost: state.cost + 1, openConsonant: false))
                        continue
                    }
                    for (cost, letter) in letters.enumerated() {
                        if state.openConsonant {
                            // Two consonants together: a conjunct, or a vowel Hindi writes but does not say.
                            expanded.append(State(text: state.text + "्" + letter, cost: state.cost + cost, openConsonant: true))
                            expanded.append(State(text: state.text + letter, cost: state.cost + cost + 1, openConsonant: true))
                        } else {
                            expanded.append(State(text: state.text + letter, cost: state.cost + cost, openConsonant: true))
                        }
                    }
                }
            }
            beam = Array(expanded.sorted { $0.cost < $1.cost }.prefix(beamWidth))
        }
        return beam.filter { !$0.text.isEmpty }
    }
}
