import Foundation

/// Emoji for the words people type, and a search over them. A fixed table on the device:
/// nothing here is learned or sent anywhere.
public final class EmojiLexicon: @unchecked Sendable {
    public static let shared = EmojiLexicon(table: EmojiKeywords.table)

    /// Keyword to emoji, best first.
    private let byKeyword: [String: [String]]
    /// Keywords in the order they were written, which is also the order search results tie-break on.
    private let keywords: [String]
    /// Every emoji in the table, once each, in table order.
    private let tableEmoji: [String]
    private let lock = NSLock()
    private var nameIndex: [String: [String]] = [:]

    init(table: String) {
        var byKeyword: [String: [String]] = [:]
        var keywords: [String] = []
        for line in table.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let emoji = parts[1].split(separator: " ").map(String.init)
            for word in parts[0].split(separator: " ").map({ String($0).lowercased() }) where byKeyword[word] == nil {
                byKeyword[word] = emoji
                keywords.append(word)
            }
        }
        self.byKeyword = byKeyword
        self.keywords = keywords
        var seen = Set<String>()
        tableEmoji = keywords.flatMap { byKeyword[$0] ?? [] }.filter { seen.insert($0).inserted }
    }

    /// Every keyword, for checking the table.
    public var allKeywords: [String] { keywords }

    /// Emoji for a whole word, best first. Empty when the word has none.
    public func emoji(for word: String) -> [String] {
        byKeyword[word.lowercased()] ?? []
    }

    /// Emoji matching every word of `query`, best first. A word matches the start of a keyword,
    /// or of a word in the emoji's Unicode name, so `chai`, `dil` and `joy` all find something.
    /// `among` is the emoji the panel shows, searched by name as well as by keyword.
    public func search(_ query: String, among catalog: [String], limit: Int = 40) -> [String] {
        let terms = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return [] }
        let names = names(for: catalog)
        var order: [String] = []
        var scores: [String: [Int]] = [:]

        func credit(_ emoji: String, term: Int, _ score: Int) {
            if scores[emoji] == nil {
                scores[emoji] = Array(repeating: 0, count: terms.count)
                order.append(emoji)
            }
            scores[emoji]![term] = max(scores[emoji]![term], score)
        }

        for (t, term) in terms.enumerated() {
            for keyword in keywords where keyword.hasPrefix(term) {
                let base = keyword == term ? 30 : 20
                for (position, emoji) in (byKeyword[keyword] ?? []).enumerated() {
                    credit(emoji, term: t, base - position)
                }
            }
            for emoji in order + catalog + tableEmoji where scores[emoji]?[t] ?? 0 < 12 {
                if let words = names[emoji], words.contains(where: { $0.hasPrefix(term) }) {
                    credit(emoji, term: t, words.contains(term) ? 12 : 10)
                }
            }
        }
        let matched = order.filter { scores[$0]!.allSatisfy { $0 > 0 } }
        let rank = Dictionary(uniqueKeysWithValues: matched.enumerated().map { ($1, $0) })
        return matched
            .sorted { lhs, rhs in
                let l = scores[lhs]!.reduce(0, +), r = scores[rhs]!.reduce(0, +)
                return l != r ? l > r : rank[lhs]! < rank[rhs]!
            }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Names

    private static let ignoredNameWords: Set<String> = ["with", "of", "and", "the", "a", "an", "sign", "symbol", "heavy"]
    private static let regionNames = Locale(identifier: "en_US")

    /// Lowercase name words for each emoji, worked out once per emoji.
    private func names(for catalog: [String]) -> [String: [String]] {
        lock.lock()
        defer { lock.unlock() }
        for emoji in catalog + tableEmoji where nameIndex[emoji] == nil {
            nameIndex[emoji] = Self.nameWords(of: emoji)
        }
        return nameIndex
    }

    static func nameWords(of emoji: String) -> [String] {
        let scalars = emoji.unicodeScalars
        // A flag is two regional indicator letters, which spell the country's code.
        let letters = scalars.compactMap { scalar -> Character? in
            guard (0x1F1E6...0x1F1FF).contains(scalar.value) else { return nil }
            return Character(Unicode.Scalar(scalar.value - 0x1F1E6 + 65)!)
        }
        var text: String
        if letters.count == 2, let country = regionNames.localizedString(forRegionCode: String(letters)) {
            text = country
        } else {
            text = scalars
                .filter { $0.value != 0x200D && $0.value != 0xFE0F && !$0.properties.isEmojiModifier }
                .compactMap { $0.properties.name }
                .joined(separator: " ")
        }
        text = text.lowercased()
        return text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !ignoredNameWords.contains($0) }
    }
}
