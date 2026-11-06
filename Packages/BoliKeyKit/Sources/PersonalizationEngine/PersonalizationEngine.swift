import Foundation
import LanguageCore
import StorageEngine

public struct VocabularyEntry: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable, Identifiable {
        case word, name, nickname, abbreviation, spelling, phrase
        public var id: String { rawValue }
        public var displayName: String {
            switch self {
            case .word: return "Word"
            case .name: return "Name"
            case .nickname: return "Nickname"
            case .abbreviation: return "Abbreviation"
            case .spelling: return "My spelling"
            case .phrase: return "Phrase"
            }
        }
    }

    public var id: String { text.lowercased() }
    public var text: String
    public var kind: Kind
    /// What an abbreviation expands to. "omw" can suggest "on my way".
    public var expansion: String?

    public init(text: String, kind: Kind, expansion: String? = nil) {
        self.text = text
        self.kind = kind
        self.expansion = expansion
    }
}

/// Things the keyboard learned, only ever from an explicit choice by the user.
public struct LearnedData: Codable, Equatable, Sendable {
    public var wordCounts: [String: Int] = [:]
    public var bigramCounts: [String: Int] = [:]
    public var phraseCounts: [String: Int] = [:]
    /// Corrections the user undid, stored as "typed>corrected". They are never repeated.
    public var rejectedCorrections: Set<String> = []
    /// Canonical word to the spelling this user prefers: "nahi" to "nhi".
    public var preferredSpellings: [String: String] = [:]
    /// Emoji the user picked, most recent first.
    public var recentEmoji: [String] = []
    /// What a word typed in English letters should become in Hindi, as this user chose it:
    /// "sita" to "सीता". A word mapped to itself stays in English letters.
    public var hindiSpellings: [String: String] = [:]
    public var resetGeneration = 0

    public init() {}

    public var isEmpty: Bool {
        wordCounts.isEmpty && bigramCounts.isEmpty && phraseCounts.isEmpty && rejectedCorrections.isEmpty && preferredSpellings.isEmpty
            && recentEmoji.isEmpty
            && hindiSpellings.isEmpty
    }

    // Tolerates missing keys, so a file from an older version keeps what it learned.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wordCounts = try c.decodeIfPresent([String: Int].self, forKey: .wordCounts) ?? [:]
        bigramCounts = try c.decodeIfPresent([String: Int].self, forKey: .bigramCounts) ?? [:]
        phraseCounts = try c.decodeIfPresent([String: Int].self, forKey: .phraseCounts) ?? [:]
        rejectedCorrections = try c.decodeIfPresent(Set<String>.self, forKey: .rejectedCorrections) ?? []
        preferredSpellings = try c.decodeIfPresent([String: String].self, forKey: .preferredSpellings) ?? [:]
        recentEmoji = try c.decodeIfPresent([String].self, forKey: .recentEmoji) ?? []
        hindiSpellings = try c.decodeIfPresent([String: String].self, forKey: .hindiSpellings) ?? [:]
        resetGeneration = try c.decodeIfPresent(Int.self, forKey: .resetGeneration) ?? 0
    }
}

public final class PersonalizationEngine {
    private let store: SharedStore
    private let lexicon: Lexicon
    public private(set) var dictionary: [VocabularyEntry] = []
    public private(set) var learned = LearnedData()
    public var isEnabled = true
    private var dictionaryIndex: [String: VocabularyEntry] = [:]
    private var dirty = false

    public init(store: SharedStore, lexicon: Lexicon = .shared) {
        self.store = store
        self.lexicon = lexicon
        reload()
    }

    /// Re-reads from disk, and honours a reset requested by the app.
    public func reload(resetGeneration: Int? = nil) {
        dictionary = store.readShared([VocabularyEntry].self, file: StoreFile.dictionary)
            ?? store.readPrivate([VocabularyEntry].self, file: StoreFile.dictionary) ?? []
        rebuildIndex()
        let shared = store.readShared(LearnedData.self, file: StoreFile.learned)
        let local = store.readPrivate(LearnedData.self, file: StoreFile.learned)
        learned = shared ?? local ?? LearnedData()
        if let generation = resetGeneration, generation != learned.resetGeneration {
            learned = LearnedData()
            learned.resetGeneration = generation
            store.remove(file: StoreFile.learned)
            persist(force: true)
        }
    }

    private func rebuildIndex() {
        dictionaryIndex = Dictionary(dictionary.map { ($0.text.lowercased(), $0) }, uniquingKeysWith: { _, new in new })
    }

    // MARK: Lookups

    public func isPersonalWord(_ word: String) -> Bool {
        let lower = word.lowercased()
        if dictionaryIndex[lower] != nil { return true }
        return isEnabled && learned.wordCounts[lower] != nil
    }

    public func entry(for word: String) -> VocabularyEntry? { dictionaryIndex[word.lowercased()] }

    public func hasRejected(typed: String, corrected: String) -> Bool {
        isEnabled && learned.rejectedCorrections.contains("\(typed.lowercased())>\(corrected.lowercased())")
    }

    public func usage(of word: String) -> Int {
        isEnabled ? (learned.wordCounts[word.lowercased()] ?? 0) : 0
    }

    public func bigramUsage(_ first: String, _ second: String) -> Int {
        isEnabled ? (learned.bigramCounts["\(first.lowercased()) \(second.lowercased())"] ?? 0) : 0
    }

    public func preferredSpelling(of canonical: String) -> String? {
        isEnabled ? learned.preferredSpellings[canonical.lowercased()] : nil
    }

    public static let recentEmojiLimit = 24

    /// Emoji the user picked, most recent first.
    public var recentEmoji: [String] { isEnabled ? learned.recentEmoji : [] }

    /// The Hindi spelling this user chose for a word typed in English letters, or the word itself
    /// when they chose to keep it in English.
    public func hindiSpelling(of roman: String) -> String? {
        isEnabled ? learned.hindiSpellings[roman.lowercased()] : nil
    }

    /// Personal words and learned phrases starting with `prefix`, most used first.
    public func completions(of prefix: String, limit: Int) -> [String] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return [] }
        var scored: [(String, Int)] = dictionary
            .filter { $0.kind != .abbreviation && $0.text.lowercased().hasPrefix(lower) && $0.text.lowercased() != lower }
            .map { ($0.text, 1_000) }
        if isEnabled {
            scored += learned.wordCounts.filter { $0.key.hasPrefix(lower) && $0.key != lower && lexicon.entry($0.key)?.flags.contains(.noSuggest) != true }
                .map { ($0.key, $0.value) }
        }
        var seen = Set<String>()
        return scored.sorted { $0.1 > $1.1 }.compactMap { seen.insert($0.0.lowercased()).inserted ? $0.0 : nil }.prefix(limit).map { $0 }
    }

    /// Frequently accepted phrases that continue what was just typed.
    public func phraseContinuations(of context: String, limit: Int) -> [String] {
        guard isEnabled, !context.isEmpty else { return [] }
        let lower = context.lowercased()
        return learned.phraseCounts
            .filter { $0.key.hasPrefix(lower + " ") }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { String($0.key.dropFirst(lower.count + 1)) }
    }

    // MARK: Learning from explicit choices

    /// The user tapped a suggestion.
    public func recordAccepted(text: String, previousWord: String?) {
        guard isEnabled else { return }
        let words = text.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return }
        if words.count > 1 { learned.phraseCounts[words.joined(separator: " "), default: 0] += 1 }
        var previous = previousWord?.lowercased()
        for word in words {
            learned.wordCounts[word, default: 0] += 1
            if let previous { learned.bigramCounts["\(previous) \(word)", default: 0] += 1 }
            previous = word
            if let canonical = lexicon.entry(word)?.canonical {
                learned.preferredSpellings[canonical] = word
            } else if lexicon.entry(word)?.flags.contains(.hinglish) == true {
                learned.preferredSpellings[word] = nil
            }
        }
        prune()
        dirty = true
    }

    /// The user chose to keep what they typed, by tapping the "as typed" suggestion.
    public func recordPreserved(word: String) {
        guard isEnabled else { return }
        learned.wordCounts[word.lowercased(), default: 0] += 1
        dirty = true
    }

    /// The user picked an emoji, from the panel or the suggestion bar.
    public func recordEmoji(_ emoji: String) {
        guard isEnabled, !emoji.isEmpty else { return }
        learned.recentEmoji.removeAll { $0 == emoji }
        learned.recentEmoji.insert(emoji, at: 0)
        if learned.recentEmoji.count > Self.recentEmojiLimit {
            learned.recentEmoji.removeLast(learned.recentEmoji.count - Self.recentEmojiLimit)
        }
        dirty = true
    }

    /// The user picked how a word typed in English letters should appear: in Devanagari, or as typed.
    public func recordHindiSpelling(roman: String, choice: String) {
        guard isEnabled, !roman.isEmpty, !choice.isEmpty else { return }
        learned.hindiSpellings[roman.lowercased()] = choice
        // Keeps the file small: past the limit, another choice makes room.
        if learned.hindiSpellings.count > 2_000, let other = learned.hindiSpellings.keys.first(where: { $0 != roman.lowercased() }) {
            learned.hindiSpellings[other] = nil
        }
        dirty = true
    }

    /// The user undid an autocorrection with backspace.
    public func recordRejectedCorrection(typed: String, corrected: String) {
        guard isEnabled else { return }
        learned.rejectedCorrections.insert("\(typed.lowercased())>\(corrected.lowercased())")
        learned.wordCounts[typed.lowercased(), default: 0] += 1
        dirty = true
    }

    /// Keeps the learned file small, dropping the least used bigrams first.
    private func prune() {
        func trim(_ table: inout [String: Int], to limit: Int) {
            guard table.count > limit else { return }
            for (key, _) in table.sorted(by: { $0.value < $1.value }).prefix(table.count - limit) { table[key] = nil }
        }
        trim(&learned.bigramCounts, to: 4_000)
        trim(&learned.wordCounts, to: 3_000)
        trim(&learned.phraseCounts, to: 500)
    }

    public func persist(force: Bool = false) {
        guard dirty || force else { return }
        store.write(learned, file: StoreFile.learned)
        dirty = false
    }

    // MARK: Dictionary management, used by the app

    public func add(_ entry: VocabularyEntry) {
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var clean = entry
        clean.text = text
        dictionary.removeAll { $0.id == clean.id }
        dictionary.append(clean)
        dictionary.sort { $0.text.lowercased() < $1.text.lowercased() }
        rebuildIndex()
        store.write(dictionary, file: StoreFile.dictionary)
    }

    public func remove(_ entry: VocabularyEntry) {
        dictionary.removeAll { $0.id == entry.id }
        rebuildIndex()
        store.write(dictionary, file: StoreFile.dictionary)
    }

    /// Erases what was learned. Words the user added by hand stay.
    public func resetLearning(generation: Int) {
        learned = LearnedData()
        learned.resetGeneration = generation
        store.remove(file: StoreFile.learned)
        persist(force: true)
    }

    /// Erases learning and the personal dictionary.
    public func clearAll(generation: Int) {
        dictionary = []
        rebuildIndex()
        store.remove(file: StoreFile.dictionary)
        resetLearning(generation: generation)
    }
}
