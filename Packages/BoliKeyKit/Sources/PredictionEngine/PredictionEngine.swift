import Foundation
import LanguageCore
import HinglishEngine
import LanguageDetectionEngine
import PersonalizationEngine

public struct Prediction: Equatable, Sendable {
    public let text: String
    public let score: Float
}

/// Statistical prediction over three per-language n-gram models, blended by the
/// language of the current sentence, and re-ranked with what this user has chosen before.
public final class PredictionEngine {
    private static let end = "</s>"
    private static let start = "<s>"
    private let lexicon: Lexicon
    private let detector: LanguageDetector
    private let personal: PersonalizationEngine

    public init(lexicon: Lexicon = .shared, detector: LanguageDetector, personal: PersonalizationEngine) {
        self.lexicon = lexicon
        self.detector = detector
        self.personal = personal
    }

    /// How much of the Hinglish and English models to use.
    public struct Blend: Equatable, Sendable {
        public var hinglish: Float
        public var english: Float
        public var devanagari: Bool
        public init(hinglish: Float, english: Float, devanagari: Bool = false) {
            self.hinglish = hinglish
            self.english = english
            self.devanagari = devanagari
        }
    }

    /// `preference` is the bias from the active language mode, from 0 (English only) to 1 (Hindi only).
    public func blend(forContext context: String, preference: Float) -> Blend {
        let analysis = detector.analyze(context)
        if analysis.dominant == .hindiDevanagari { return Blend(hinglish: 0, english: 0, devanagari: true) }
        let hasWords = analysis.tokens.contains { $0.token.kind == .word }
        let share = hasWords ? Float(analysis.hindiShare) : preference
        // Evidence from the sentence counts for more than the preference, without erasing it.
        let hindi = min(0.95, max(0.05, share * 0.75 + preference * 0.25))
        return Blend(hinglish: hindi, english: 1 - hindi)
    }

    private func contextWords(_ context: String) -> [String] {
        let sentence = Tokenizer.currentSentence(in: context)
        let tokens = Tokenizer.tokenize(sentence).filter { $0.kind == .word || $0.kind == .number }
        return tokens.map { lexicon.canonical(of: $0.text) }
    }

    /// The most likely next words after `context`.
    public func nextWords(context: String, blend: Blend, limit: Int = 3) -> [Prediction] {
        let words = contextWords(context)
        var scores: [String: Float] = [:]
        accumulate(words: words, blend: blend, into: &scores)
        // Personal bigrams count as evidence on top of the shipped model.
        if let last = words.last {
            for (key, count) in personal.learned.bigramCounts where personal.isEnabled && key.hasPrefix(last + " ") {
                let next = String(key.dropFirst(last.count + 1))
                scores[next, default: 0] += Float(min(count, 6)) * 0.35
            }
        }
        scores[Self.end] = nil
        return rank(scores, limit: limit)
    }

    private func accumulate(words: [String], blend: Blend, into scores: inout [String: Float]) {
        let first = words.count >= 2 ? words[words.count - 2] : Self.start
        let second = words.last ?? Self.start
        func add(_ language: NGramModel.Language, weight: Float) {
            guard weight > 0 else { return }
            if words.count >= 1 {
                for n in lexicon.ngrams.next(after: first, second, in: language) { scores[n.word, default: 0] += n.probability * weight * 0.7 }
            }
            for n in lexicon.ngrams.next(after: second, in: language) { scores[n.word, default: 0] += n.probability * weight * 0.3 }
        }
        if blend.devanagari {
            add(.devanagari, weight: 1)
        } else {
            add(.hinglish, weight: blend.hinglish)
            add(.english, weight: blend.english)
        }
    }

    private func rank(_ scores: [String: Float], limit: Int) -> [Prediction] {
        scores.filter { suggestable($0.key) }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { Prediction(text: personal.preferredSpelling(of: $0.key) ?? $0.key, score: $0.value) }
    }

    private func suggestable(_ word: String) -> Bool {
        if personal.usage(of: word) > 0 { return true }
        return lexicon.entries[word]?.flags.contains(.noSuggest) != true
    }

    /// Continuations of more than one word: "kal kya" gives "plan hai", "scene hai" and "karna hai".
    /// A small beam search that stops where messages in the corpus usually stop.
    public func phrases(context: String, blend: Blend, limit: Int = 3, maxWords: Int = 4) -> [Prediction] {
        let words = contextWords(context)
        guard !words.isEmpty else { return [] }

        struct Beam { var words: [String]; var added: [String]; var score: Float; var closed: Bool }
        var beams = [Beam(words: words, added: [], score: 1, closed: false)]
        var finished: [Beam] = []
        for _ in 0..<maxWords {
            var expanded: [Beam] = []
            for beam in beams {
                var scores: [String: Float] = [:]
                accumulate(words: beam.words, blend: blend, into: &scores)
                for (word, p) in scores.sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }).prefix(5) {
                    if word == Self.end {
                        if !beam.added.isEmpty { finished.append(Beam(words: beam.words, added: beam.added, score: beam.score * p, closed: true)) }
                    } else if suggestable(word) {
                        expanded.append(Beam(words: beam.words + [word], added: beam.added + [word], score: beam.score * p, closed: false))
                    }
                }
            }
            beams = Array(expanded.sorted { $0.score > $1.score }.prefix(8))
            if beams.isEmpty { break }
        }
        // Phrases of two or more words are what this slot adds beyond next-word prediction.
        var seen = Set<String>()
        let multi = finished.filter { $0.added.count >= 2 }
            .sorted { $0.score == $1.score ? $0.added.joined() < $1.added.joined() : $0.score > $1.score }
            .filter { seen.insert($0.added.joined(separator: " ")).inserted }
        var results = multi.prefix(limit).map { beam in
            Prediction(text: beam.added.map { personal.preferredSpelling(of: $0) ?? $0 }.joined(separator: " "), score: beam.score)
        }
        // What this user has chosen before comes first.
        let learned = personal.phraseContinuations(of: words.joined(separator: " "), limit: limit)
        for phrase in learned.reversed() {
            results.removeAll { $0.text == phrase }
            results.insert(Prediction(text: phrase, score: 1), at: 0)
        }
        return Array(results.prefix(limit))
    }

    /// Completions of a partly typed word, ranked using the sentence so far.
    public func completions(prefix: String, context: String, blend: Blend, limit: Int = 3) -> [Prediction] {
        let lower = prefix.lowercased()
        guard !lower.isEmpty else { return [] }
        let words = contextWords(context)
        var nextScores: [String: Float] = [:]
        accumulate(words: words, blend: blend, into: &nextScores)

        let trie = blend.devanagari ? lexicon.devanagariTrie : lexicon.latinTrie
        var scored: [String: Float] = [:]
        for match in trie.completions(of: lower, limit: 24) where match.word != lower {
            guard let entry = lexicon.entries[match.word], !entry.flags.contains(.noSuggest) else { continue }
            var score: Float
            if blend.devanagari {
                score = Float(log10(max(1, Double(match.score))))
            } else {
                score = match.score * 0.3
                let isHindi = entry.flags.contains(.hinglish)
                let isEnglish = entry.flags.contains(.english)
                score += (isHindi ? blend.hinglish : 0) * 1.1 + (isEnglish ? blend.english : 0) * 1.1
            }
            score += (nextScores[entry.canonicalOrSelf] ?? 0) * 6
            scored[match.word] = score
        }
        // Words that the n-gram model expects here, even if they are rare overall.
        for (word, p) in nextScores where word.hasPrefix(lower) && word != lower && word != Self.end {
            scored[word] = max(scored[word] ?? 0, p * 6 + 1.5)
        }
        for word in personal.completions(of: lower, limit: limit) {
            scored[word, default: 0] += 3 + Float(min(personal.usage(of: word), 6)) * 0.5
        }
        return scored.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { Prediction(text: $0.key, score: $0.value) }
    }
}
