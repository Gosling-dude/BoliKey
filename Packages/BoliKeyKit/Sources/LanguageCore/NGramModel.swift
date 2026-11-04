import Foundation

/// A per-language n-gram table. Contexts map to next words with conditional probabilities.
public final class NGramModel {
    public enum Language: Hashable, Sendable { case hinglish, english, devanagari }

    public struct Next: Sendable {
        public let word: String
        public let probability: Float
    }

    private var bigrams: [Language: [String: [Next]]] = [:]
    private var trigrams: [Language: [String: [Next]]] = [:]

    public init() {}

    func parse(_ data: Data) {
        var rawBi: [Language: [String: [(String, Int)]]] = [:]
        var rawTri: [Language: [String: [(String, Int)]]] = [:]
        forEachLine(data) { f in
            guard f.count == 5, let c = Int(f[4]) else { return }
            let lang: Language
            switch f[0] {
            case "h": lang = .hinglish
            case "e": lang = .english
            default: lang = .devanagari
            }
            if f[1] == "2" {
                rawBi[lang, default: [:]][f[2], default: []].append((f[3], c))
            } else {
                rawTri[lang, default: [:]][f[2], default: []].append((f[3], c))
            }
        }
        func normalise(_ raw: [Language: [String: [(String, Int)]]]) -> [Language: [String: [Next]]] {
            raw.mapValues { table in
                table.mapValues { rows in
                    let total = Float(rows.reduce(0) { $0 + $1.1 })
                    return rows.sorted { $0.1 > $1.1 }.map { Next(word: $0.0, probability: Float($0.1) / total) }
                }
            }
        }
        bigrams = normalise(rawBi)
        trigrams = normalise(rawTri)
    }

    public func next(after word: String, in language: Language) -> [Next] {
        bigrams[language]?[word] ?? []
    }

    public func next(after first: String, _ second: String, in language: Language) -> [Next] {
        trigrams[language]?["\(first) \(second)"] ?? []
    }
}
