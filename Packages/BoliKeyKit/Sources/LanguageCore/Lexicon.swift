import Foundation

public struct WordFlags: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let hinglish = WordFlags(rawValue: 1 << 0)
    public static let english = WordFlags(rawValue: 1 << 1)
    public static let devanagari = WordFlags(rawValue: 1 << 2)
    /// Used in Hinglish messages without being a Hindi word: "bgmi", "gpay".
    public static let loanword = WordFlags(rawValue: 1 << 3)
    /// Recognised, but never proposed by the keyboard.
    public static let noSuggest = WordFlags(rawValue: 1 << 4)
}

public struct WordEntry: Sendable {
    public let word: String
    public let flags: WordFlags
    public let hindiCount: Int32
    public let englishCount: Int32
    public let canonical: String?
    public let devanagari: String?
    public let gloss: String?

    public var canonicalOrSelf: String { canonical ?? word }
}

/// The vocabulary, looked up in place in the mapped word table.
public struct EntryTable: Sequence {
    let table: MappedTable?

    public var count: Int { table?.count ?? 0 }

    public subscript(word: String) -> WordEntry? {
        guard let table else { return nil }
        let range = table.equalRange(of: word)
        guard let index = range.first else { return nil }
        return Self.decode(table.fields(at: index))
    }

    static func decode(_ fields: [String]) -> WordEntry? {
        guard fields.count >= 7 else { return nil }
        var flags: WordFlags = []
        for ch in fields[1] {
            switch ch {
            case "h": flags.insert(.hinglish)
            case "e": flags.insert(.english)
            case "d": flags.insert(.devanagari)
            case "l": flags.insert(.loanword)
            case "n": flags.insert(.noSuggest)
            default: break
            }
        }
        return WordEntry(word: fields[0], flags: flags,
                         hindiCount: Int32(clamping: Int(fields[2]) ?? 0), englishCount: Int32(clamping: Int(fields[3]) ?? 0),
                         canonical: fields[4].isEmpty ? nil : fields[4],
                         devanagari: fields[5].isEmpty ? nil : fields[5],
                         gloss: fields[6].isEmpty ? nil : fields[6])
    }

    public func makeIterator() -> AnyIterator<(String, WordEntry)> {
        var i = 0
        return AnyIterator {
            guard let table = self.table else { return nil }
            while i < table.count {
                defer { i += 1 }
                if let e = Self.decode(table.fields(at: i)) { return (e.word, e) }
            }
            return nil
        }
    }
}

/// The read-only language model: vocabulary, n-grams and character statistics.
/// Loaded once, off the main thread, and shared by every engine.
public final class Lexicon {
    public private(set) var entries = EntryTable(table: nil)
    public let latinTrie = Trie()
    public let devanagariTrie = Trie()
    public let ngrams = NGramModel()
    private var charGrams: [String: (hi: Float, en: Float)] = [:]
    private var charFloor: (hi: Float, en: Float) = (-12, -12)
    private var romanByDevanagari: [String: String] = [:]
    public private(set) var hindiTotal: Double = 1
    public private(set) var englishTotal: Double = 1
    private static let homographEnglishCount: Int32 = 10_000
    private static let homographEvidenceCap = 1.4

    public static let shared: Lexicon = {
        guard let lexicon = try? Lexicon(bundle: .module) else {
            assertionFailure("BoliKey language resources are missing from the bundle")
            return Lexicon()
        }
        return lexicon
    }()

    /// An empty model. Everything stays usable, it simply knows no words.
    public init() {}

    public init(bundle: Bundle) throws {
        try load(from: bundle)
    }

    public enum LoadError: Error { case missing(String) }

    private func resource(_ name: String, in bundle: Bundle) throws -> Data {
        let url = bundle.url(forResource: name, withExtension: "tsv", subdirectory: "LanguageData")
            ?? bundle.url(forResource: name, withExtension: "tsv")
        guard let url else { throw LoadError.missing(name) }
        return try Data(contentsOf: url, options: .alwaysMapped)
    }

    private func load(from bundle: Bundle) throws {
        try parseWords(resource("words", in: bundle))
        try ngrams.parse(resource("ngrams", in: bundle))
        try parseCharGrams(resource("chargrams", in: bundle))
    }

    private func parseWords(_ data: Data) {
        latinTrie.reserve(40_000)
        entries = EntryTable(table: MappedTable(data: data))
        forEachLine(data) { fields in
            guard fields.count >= 7 else { return }
            let word = fields[0]
            let hi = Int32(clamping: Int(fields[2]) ?? 0)
            let en = Int32(clamping: Int(fields[3]) ?? 0)
            hindiTotal += Double(hi)
            englishTotal += Double(en)
            if fields[1].contains("d") {
                devanagariTrie.insert(word, score: Float(hi))
            } else {
                latinTrie.insert(word, score: unigramScore(hi: hi, en: en))
                if !fields[5].isEmpty, fields[4].isEmpty, romanByDevanagari[fields[5]] == nil {
                    romanByDevanagari[fields[5]] = word
                }
            }
        }
    }

    /// A single comparable log-frequency across the two very differently scaled sources.
    private func unigramScore(hi: Int32, en: Int32) -> Float {
        Float(max(log10(Double(max(hi, 1))) * 1.6, log10(Double(max(en, 1)))))
    }

    private func parseCharGrams(_ data: Data) {
        forEachLine(data) { fields in
            guard fields.count == 3, let hi = Float(fields[1]), let en = Float(fields[2]) else { return }
            if fields[0] == "#floor" {
                charFloor = (hi, en)
            } else {
                charGrams[fields[0]] = (hi, en)
            }
        }
    }

    public func entry(_ word: String) -> WordEntry? {
        let lower = word.lowercased()
        return entries[lower] ?? (lower == word ? nil : entries[word])
    }

    public func isKnown(_ word: String) -> Bool { entry(word) != nil }

    public func canonical(of word: String) -> String { entry(word)?.canonical ?? word.lowercased() }

    public func roman(forDevanagari word: String) -> String? { romanByDevanagari[word] }

    /// P(word | Hindi) and P(word | English), as logs, from the shipped counts.
    /// Devanagari never reaches this: it is identified by script alone.
    public func logLikelihoods(_ word: String) -> (hi: Double, en: Double) {
        let lower = word.lowercased()
        let fromChars = charGramLogs(lower)
        guard let e = entries[lower] else { return (fromChars.hi - 8, fromChars.en - 8) }
        let hi = e.hindiCount > 0 ? log((Double(e.hindiCount) + 0.5) / hindiTotal) : -18.0
        let en = e.englishCount > 0 ? log((Double(e.englishCount) + 0.5) / englishTotal) : -22.0
        // True homographs ("the", "main", "to") are common in both languages. Their evidence is
        // capped below the cost of a language switch, so the surrounding words decide.
        // The threshold skips Hindi words that merely appear in the subtitle frequency list.
        if e.flags.contains(.hinglish), e.englishCount >= Self.homographEnglishCount {
            let diff = hi - en
            let capped = Swift.max(-Self.homographEvidenceCap, Swift.min(Self.homographEvidenceCap, diff))
            return (en + capped, en)
        }
        return (hi, en)
    }

    /// Naive Bayes over character trigrams, for words no list knows: "pahuchgya".
    public func charGramLogs(_ word: String) -> (hi: Double, en: Double) {
        let chars = Array("^\(word)$")
        guard chars.count >= 3 else { return (-10, -10) }
        var hi: Float = 0, en: Float = 0
        for i in 0..<(chars.count - 2) {
            let g = String(chars[i...(i + 2)])
            let row = charGrams[g] ?? charFloor
            hi += row.hi
            en += row.en
        }
        let n = Float(chars.count - 2)
        // Normalised by length, so that long words do not swamp the sequence model.
        return (Double(hi / n), Double(en / n))
    }
}

/// Iterates tab-separated lines without creating intermediate arrays of lines.
func forEachLine(_ data: Data, _ body: ([String]) -> Void) {
    data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
        guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
        var start = 0
        let count = raw.count
        var i = 0
        var fields: [String] = []
        fields.reserveCapacity(8)
        while i <= count {
            if i == count || base[i] == 10 || base[i] == 9 {
                let buf = UnsafeBufferPointer(start: base + start, count: i - start)
                fields.append(String(decoding: buf, as: UTF8.self))
                start = i + 1
                if i == count || base[i] == 10 {
                    if fields.count > 1 { body(fields) }
                    fields.removeAll(keepingCapacity: true)
                }
            }
            i += 1
        }
    }
}

extension Lexicon {
    /// The bundle holding the language resources.
    public static var resourceBundle: Bundle { .module }
}
