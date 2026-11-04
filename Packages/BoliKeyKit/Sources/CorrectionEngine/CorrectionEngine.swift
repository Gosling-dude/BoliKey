import Foundation
import LanguageCore
import HinglishEngine
import LanguageDetectionEngine
import PersonalizationEngine

/// Why a token was left exactly as typed.
public enum PreserveReason: Equatable, Sendable {
    case personalVocabulary, knownHinglish, knownEnglish, devanagari, shortForm, elongation
    case symbolic, mixedCase, numeric, readsAsHindi, noConfidentFix, correctionRejected, disabled
}

public struct Candidate: Equatable, Sendable {
    public let word: String
    public let cost: Float
    public let score: Float
}

public enum CorrectionDecision: Equatable, Sendable {
    /// PRESERVE: keep the input. Candidates may still be offered, never applied.
    case preserve(PreserveReason, candidates: [Candidate])
    /// CORRECT: a genuine typo, confident enough to fix. Backspace undoes it.
    case correct(Candidate, alternatives: [Candidate])
}

/// The three operations are separate on purpose.
/// PRESERVE is the default, CORRECT needs strong evidence, and IMPROVE is only ever offered.
public final class CorrectionEngine {
    private let lexicon: Lexicon
    private let hinglish: HinglishEngine
    private let detector: LanguageDetector
    private let personal: PersonalizationEngine
    private let costModel = EditCostModel()

    public init(lexicon: Lexicon = .shared, hinglish: HinglishEngine, detector: LanguageDetector, personal: PersonalizationEngine) {
        self.lexicon = lexicon
        self.hinglish = hinglish
        self.detector = detector
        self.personal = personal
    }

    /// Decides what may happen to the word just finished.
    /// - Parameter context: the text before the word, used for its language.
    public func decide(word: String, context: String, autoCorrectEnabled: Bool) -> CorrectionDecision {
        if personal.isPersonalWord(word) { return .preserve(.personalVocabulary, candidates: []) }
        if Tokenizer.isSymbolic(word) { return .preserve(.symbolic, candidates: []) }
        if word.contains(where: { $0.isNumber }) { return .preserve(.numeric, candidates: []) }
        switch Script.of(word) {
        case .latin: break
        case .devanagari: return .preserve(.devanagari, candidates: [])
        default: return .preserve(.noConfidentFix, candidates: [])
        }
        let lower = word.lowercased()
        // iPhone, LinkedIn, NASA: deliberate casing is deliberate.
        let hasInnerCapital = word.dropFirst().contains { $0.isUppercase }
        if hasInnerCapital { return .preserve(.mixedCase, candidates: []) }
        if let entry = lexicon.entry(lower) {
            if entry.flags.contains(.hinglish) || entry.flags.contains(.loanword) { return .preserve(.knownHinglish, candidates: []) }
            return .preserve(.knownEnglish, candidates: [])
        }
        if let collapsed = hinglish.collapseElongation(lower) {
            return .preserve(.elongation, candidates: [Candidate(word: collapsed, cost: 0.5, score: 0)])
        }
        // "k", "ok", "np", "sb": too short to be sure of anything.
        if lower.count <= 2 { return .preserve(.shortForm, candidates: []) }

        let phonetic = hinglish.phoneticMatches(lower)
        let candidates = rank(lower, context: context)
        let hindiLike = !phonetic.isEmpty || hinglish.readsAsHindi(lower)

        guard let best = candidates.first else {
            return .preserve(hindiLike ? .readsAsHindi : .noConfidentFix, candidates: phonetic.prefix(2).map { Candidate(word: $0, cost: 1, score: 0) })
        }
        guard autoCorrectEnabled else { return .preserve(.disabled, candidates: candidates) }
        if personal.hasRejected(typed: lower, corrected: best.word) {
            return .preserve(.correctionRejected, candidates: candidates)
        }
        // A capitalised word in mid-sentence is probably a name.
        if word.first?.isUppercase == true, !context.trimmingCharacters(in: .whitespaces).isEmpty,
           !".!?\n".contains(context.trimmingCharacters(in: .whitespaces).last ?? ".") {
            return .preserve(.noConfidentFix, candidates: candidates)
        }
        guard isConfident(typed: lower, best: best, runnerUp: candidates.dropFirst().first, hindiLike: hindiLike, phonetic: phonetic) else {
            return .preserve(hindiLike ? .readsAsHindi : .noConfidentFix, candidates: candidates)
        }
        return .correct(best, alternatives: Array(candidates.dropFirst()))
    }

    private func isConfident(typed: String, best: Candidate, runnerUp: Candidate?, hindiLike: Bool, phonetic: [String]) -> Bool {
        let length = typed.count
        let limit: Float
        switch length {
        case ...3: limit = 0.55 // Only a swap: "teh" to "the".
        case 4: limit = 0.7
        case 5...6: limit = 0.85
        default: limit = 1.45
        }
        guard best.cost <= limit else { return false }
        // Reads as Hindi and is not obviously that word: this could be a spelling we simply do not know.
        // A clean swap or doubled letter is still a typo, and that holds in either language.
        if hindiLike, best.cost > 0.6, !phonetic.contains(best.word) { return false }
        // Two plausible fixes mean we do not know which one the user meant.
        if let runnerUp, best.score - runnerUp.score < 0.55 { return false }
        return true
    }

    /// Candidate fixes, best first. Never includes words the keyboard must not propose.
    public func rank(_ word: String, context: String, limit: Int = 3) -> [Candidate] {
        let lower = word.lowercased()
        let maxCost: Float = lower.count <= 3 ? 1.0 : (lower.count <= 6 ? 1.4 : 2.0)
        var matches = lexicon.latinTrie.fuzzySearch(lower, maxCost: maxCost, cost: costModel)
        // A trie search is capped by edit cost, and very rare words add only noise here.
        matches = matches.filter { $0.word != lower }
        let hindiShare = detector.analyze(context).hindiShare
        let hasContext = !context.trimmingCharacters(in: .whitespaces).isEmpty
        let scored: [Candidate] = matches.compactMap { match in
            guard let entry = lexicon.entries[match.word], !entry.flags.contains(.noSuggest), match.word.count > 1 else { return nil }
            // A word no conversation uses is rarely what was meant.
            let isHindi = entry.flags.contains(.hinglish)
            let frequency = match.score
            var score = frequency * 0.42 - match.cost * 2.6
            if hasContext {
                score += isHindi ? Float(hindiShare) * 0.7 : Float(1 - hindiShare) * 0.7
            }
            score += Float(min(personal.usage(of: match.word), 5)) * 0.3
            return Candidate(word: entry.canonical ?? match.word, cost: match.cost, score: score)
        }
        var seen = Set<String>()
        return scored.sorted { $0.score > $1.score }
            .filter { seen.insert($0.word).inserted }
            .prefix(limit).map { $0 }
    }

    // MARK: Sentence level

    public struct SentenceOptions: Equatable, Sendable {
        public let original: String
        /// Conventional spellings, same language and same words.
        public let normalised: String?
        /// Comma after an opening address term: "bhai, mai ...".
        public let punctuated: String?
        /// An optional improved phrasing from the rules file.
        public let improved: String?
    }

    /// IMPROVE: options for a whole sentence. The caller only ever offers these.
    public func sentenceOptions(for sentence: String) -> SentenceOptions? {
        let analysis = detector.analyze(sentence)
        let words = analysis.tokens.filter { $0.token.kind == .word }
        guard words.count >= 2, analysis.hindiShare > 0 else { return nil }
        var rebuilt = sentence
        var changed = false
        var searchStart = rebuilt.startIndex
        for tagged in analysis.tokens {
            guard let range = rebuilt.range(of: tagged.token.text, range: searchStart..<rebuilt.endIndex) else { continue }
            var replacement = tagged.token.text
            if tagged.token.kind == .word, tagged.language == .hindiRoman,
               let fixed = hinglish.conventionalSpelling(of: tagged.token.text) {
                replacement = Self.matchCase(of: tagged.token.text, in: fixed)
                changed = true
            }
            rebuilt.replaceSubrange(range, with: replacement)
            searchStart = rebuilt.index(range.lowerBound, offsetBy: replacement.count)
        }
        let normalised = changed ? rebuilt : nil
        let base = normalised ?? sentence
        let improved = hinglish.improved(base)
        var punctuated: String?
        let addressTerms: Set<String> = ["bhai", "yaar", "sir", "madam", "didi", "bhaiya", "boss", "arre", "dost", "beta", "oye", "abe", "haan", "nahi", "accha"]
        if let first = words.first?.token.text, addressTerms.contains(first.lowercased()),
           words.count >= 3, !sentence.dropFirst(first.count).hasPrefix(",") {
            punctuated = first + "," + sentence.dropFirst(first.count)
        }
        guard normalised != nil || improved != nil || punctuated != nil else { return nil }
        return SentenceOptions(original: sentence, normalised: normalised, punctuated: punctuated, improved: improved)
    }

    static func matchCase(of original: String, in replacement: String) -> String {
        guard let first = original.first, first.isUppercase else { return replacement }
        if original.count > 1, original == original.uppercased() { return replacement.uppercased() }
        return replacement.prefix(1).uppercased() + replacement.dropFirst()
    }
}
