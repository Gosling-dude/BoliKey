import Foundation
import LanguageCore

public struct TaggedToken: Equatable, Sendable {
    public let token: Token
    public let language: LanguageTag
}

public struct SentenceAnalysis: Sendable {
    public let tokens: [TaggedToken]
    /// The share of words identified as Hindi, in either script, from 0 to 1.
    public let hindiShare: Double
    public var isCodeSwitched: Bool {
        let tags = Set(tokens.map(\.language).filter { $0 == .english || $0.isHindi })
        return tags.count > 1
    }
    public var dominant: LanguageTag {
        let words = tokens.filter { $0.token.kind == .word }
        if words.contains(where: { $0.language == .hindiDevanagari }) { return .hindiDevanagari }
        if words.isEmpty { return .neutral }
        return hindiShare >= 0.5 ? .hindiRoman : .english
    }
}

/// Tags every token with its language using a two-state hidden Markov model.
///
/// Script decides Devanagari outright. For Roman text the states are Hindi and English.
/// Emissions come from the shipped word counts, or character statistics for unknown
/// words. Transitions model that speakers tend to stay in a language, which is what
/// separates "the" in "going to the office" from "the" in "kal tum wahan the".
public struct LanguageDetector {
    private let lexicon: Lexicon
    /// Log probability of staying in the same language between two words.
    private let stay = log(0.84)
    private let change = log(0.16)
    /// The profile's language preference, as a small log-odds bias toward Hindi.
    public var hindiBias: Double

    public init(lexicon: Lexicon = .shared, hindiBias: Double = 0) {
        self.lexicon = lexicon
        self.hindiBias = hindiBias
    }

    public func analyze(_ text: String) -> SentenceAnalysis {
        let tokens = Tokenizer.tokenize(text)
        let tags = tag(tokens)
        let pairs = zip(tokens, tags).map { TaggedToken(token: $0, language: $1) }
        let words = pairs.filter { $0.token.kind == .word && $0.language != .other }
        let hindi = words.filter { $0.language.isHindi }.count
        return SentenceAnalysis(tokens: pairs, hindiShare: words.isEmpty ? 0 : Double(hindi) / Double(words.count))
    }

    private func tag(_ tokens: [Token]) -> [LanguageTag] {
        var result = [LanguageTag](repeating: .neutral, count: tokens.count)
        var roman: [Int] = []
        for (i, token) in tokens.enumerated() {
            switch token.kind {
            case .word:
                switch Script.of(token.text) {
                case .devanagari: result[i] = .hindiDevanagari
                case .latin: roman.append(i)
                case .digit, .symbol: result[i] = .neutral
                default: result[i] = .other
                }
            default:
                result[i] = .neutral
            }
        }
        guard !roman.isEmpty else { return result }

        // Viterbi over the Roman words only. Numbers and punctuation neither help nor break a run.
        var hiScore = 0.0, enScore = 0.0
        var back: [(hi: Bool, en: Bool)] = []
        for (n, i) in roman.enumerated() {
            let e = lexicon.logLikelihoods(tokens[i].text)
            let hiEmission = e.hi + hindiBias
            if n == 0 {
                hiScore = hiEmission
                enScore = e.en
                back.append((true, false))
                continue
            }
            let hiFromHi = hiScore + stay, hiFromEn = enScore + change
            let enFromEn = enScore + stay, enFromHi = hiScore + change
            back.append((hi: hiFromHi >= hiFromEn, en: enFromHi > enFromEn))
            hiScore = max(hiFromHi, hiFromEn) + hiEmission
            enScore = max(enFromEn, enFromHi) + e.en
        }
        var state = hiScore >= enScore
        for n in stride(from: roman.count - 1, through: 0, by: -1) {
            result[roman[n]] = state ? .hindiRoman : .english
            if n > 0 { state = state ? back[n].hi : back[n].en }
        }
        return result
    }
}
