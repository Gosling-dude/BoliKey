import Foundation
import LanguageCore
import HinglishEngine
import StorageEngine

public struct Rewrite: Equatable, Sendable {
    public enum Method: String, Sendable {
        /// Matched a sentence pattern and was translated by rule.
        case pattern
        /// Same words and language, with tone adjustments only.
        case polish
        /// Produced by a model behind `RewriteProvider`. No such provider ships yet.
        case provider
    }
    public let style: WritingStyle
    public let text: String
    public let method: Method
}

/// A future rewriting backend: on-device or user-enabled cloud. Never called while typing.
public protocol RewriteProvider {
    func rewrite(_ text: String, style: WritingStyle) async throws -> String
}

/// Offline rewriting by transparent rules. Every result is an option the user taps.
///
/// This is deliberately not presented as AI. It handles a fixed set of Hinglish sentence
/// patterns and common tone edits. When nothing matches, it adjusts tone without
/// pretending to translate.
public struct WritingEngine {
    private let lexicon: Lexicon
    private let hinglish: HinglishEngine

    public init(lexicon: Lexicon = .shared, hinglish: HinglishEngine) {
        self.lexicon = lexicon
        self.hinglish = hinglish
    }

    public func rewrites(of text: String, styles: [WritingStyle] = WritingStyle.allCases) -> [Rewrite] {
        styles.compactMap { rewrite(text, style: $0) }
    }

    public func rewrite(_ text: String, style: WritingStyle) -> Rewrite? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let meaning = PatternMatcher.match(trimmed, lexicon: lexicon)
        let result: (String, Rewrite.Method)
        switch style {
        case .casual:
            result = (casual(trimmed), .polish)
        case .friendly:
            result = (friendly(trimmed), .polish)
        case .playful:
            result = (playful(trimmed), .polish)
        case .short:
            result = (short(trimmed), .polish)
        case .professional:
            if let meaning { result = (meaning.professional, .pattern) } else { result = (professional(trimmed), .polish) }
        case .formal:
            if let meaning { result = (meaning.formal, .pattern) } else { result = (formal(trimmed), .polish) }
        }
        return Rewrite(style: style, text: result.0, method: result.1)
    }

    // MARK: Tone rules

    private static let questionWords: Set<String> = ["kya", "kyun", "kyu", "kab", "kaise", "kahan", "kaha", "kaun", "kitna", "kitni", "kitne", "kidhar",
                                                     "what", "when", "where", "why", "who", "how", "can", "could", "would", "will", "do", "does", "did", "is", "are", "should"]

    private func isQuestion(_ text: String) -> Bool {
        if text.hasSuffix("?") { return true }
        let words = text.lowercased().split(separator: " ").map(String.init)
        guard let first = words.first, let last = words.last else { return false }
        if ["kya", "na"].contains(last) { return true }
        let englishLeads: Set<String> = ["what", "when", "where", "why", "who", "how", "can", "could", "would", "do", "does", "did", "should", "are", "is"]
        if englishLeads.contains(first) { return true }
        let hindiQuestion: Set<String> = ["kya", "kyun", "kyu", "kab", "kaise", "kahan", "kaha", "kaun", "kitna", "kitni", "kitne", "kidhar"]
        // "pata nahi kya" aside, a Hindi question word near the start marks a question.
        return words.prefix(3).contains { hindiQuestion.contains($0) }
    }

    private func endPunctuated(_ text: String) -> String {
        if let last = text.last, ".!?।".contains(last) { return text }
        return text + (isQuestion(text) ? "?" : "")
    }

    private func sentenceCased(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private func withPeriod(_ text: String) -> String {
        if let last = text.last, ".!?।".contains(last) { return text }
        return text + (isQuestion(text) ? "?" : ".")
    }

    private func casual(_ text: String) -> String { endPunctuated(text) }

    private func friendly(_ text: String) -> String {
        let body = endPunctuated(text)
        let lower = body.lowercased()
        let greetings = ["hey", "hi ", "hello", "arre", "oye", "namaste"]
        if greetings.contains(where: { lower.hasPrefix($0) }) { return body }
        return "Hey, " + body
    }

    private func playful(_ text: String) -> String {
        let base = endPunctuated(text)
        return base + (isQuestion(base) ? " 🤔" : " 😄")
    }

    private static let fillers: Set<String> = ["bhai", "yaar", "actually", "basically", "literally", "matlab", "bas", "arre", "just", "really", "very", "bahut", "please", "kindly", "toh", "umm", "like"]

    private func short(_ text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        let kept = words.filter { !Self.fillers.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
        let out = kept.isEmpty ? words : kept
        return endPunctuated(out.joined(separator: " "))
    }

    private static let informalEnglish: [(String, String)] = [
        ("gonna", "going to"), ("wanna", "want to"), ("gotta", "have to"), ("kinda", "somewhat"), ("u", "you"), ("ur", "your"), ("r", "are"),
        ("pls", "please"), ("plz", "please"), ("thx", "thanks"), ("thnx", "thanks"), ("msg", "message"), ("tmrw", "tomorrow"), ("tmr", "tomorrow"),
        ("omw", "on my way"), ("idk", "I do not know"), ("btw", "by the way"), ("asap", "as soon as possible"), ("ok", "okay"), ("yeah", "yes"), ("yep", "yes"), ("nope", "no"),
        ("i", "I"),
    ]

    private static let contractions: [(String, String)] = [
        ("don't", "do not"), ("can't", "cannot"), ("won't", "will not"), ("i'm", "I am"), ("i'll", "I will"), ("it's", "it is"), ("didn't", "did not"),
        ("doesn't", "does not"), ("isn't", "is not"), ("wasn't", "was not"), ("we're", "we are"), ("you're", "you are"), ("let's", "let us"), ("i've", "I have"), ("i'd", "I would"), ("that's", "that is"), ("what's", "what is"),
    ]

    private func replaceWords(_ text: String, _ table: [(String, String)]) -> String {
        let map = Dictionary(table, uniquingKeysWith: { a, _ in a })
        return text.split(separator: " ", omittingEmptySubsequences: true).map { raw -> String in
            let word = String(raw)
            let bare = word.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ",.!?"))
            guard let replacement = map[bare] else { return word }
            let trail = word.reversed().prefix { ",.!?".contains($0) }
            return replacement + String(trail.reversed())
        }.joined(separator: " ")
    }

    private func professional(_ text: String) -> String {
        let cleaned = replaceWords(text, Self.informalEnglish)
        let noFiller = cleaned.split(separator: " ").filter { !["bhai", "yaar", "arre", "bro", "dude"].contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }.joined(separator: " ")
        return withPeriod(sentenceCased(noFiller.isEmpty ? cleaned : noFiller))
    }

    private func formal(_ text: String) -> String {
        withPeriod(sentenceCased(replaceWords(professional(text).trimmingCharacters(in: CharacterSet(charactersIn: ".")), Self.contractions)))
    }
}

/// Fixed Hinglish sentence shapes the rules can express properly in English.
struct PatternMatcher {
    struct Meaning {
        let professional: String
        let formal: String
    }

    private static let time: [String: String] = [
        "kal": "tomorrow", "aaj": "today", "parso": "the day after tomorrow", "abhi": "right now",
        "subah": "this morning", "shaam": "this evening", "raat": "tonight",
    ]

    private struct Rule {
        /// `$T` matches a time word, `$X` one or more other words.
        let pattern: [String]
        let professional: String
        let formal: String
    }

    private static let rules: [Rule] = [
        .init(pattern: ["$T", "$X", "hai", "kya"], professional: "Is there a $X scheduled for $T?", formal: "Could you please confirm whether a $X is scheduled for $T?"),
        .init(pattern: ["$X", "hai", "kya", "$T"], professional: "Is there a $X scheduled for $T?", formal: "Could you please confirm whether a $X is scheduled for $T?"),
        .init(pattern: ["$X", "kab", "hai"], professional: "When is the $X scheduled?", formal: "Could you please let me know when the $X is scheduled?"),
        .init(pattern: ["$X", "kitne", "baje", "hai"], professional: "What time is the $X?", formal: "Could you please let me know what time the $X is scheduled?"),
        .init(pattern: ["main", "$T", "$X", "nahi", "aa", "paunga"], professional: "I will not be able to come to the $X $T.", formal: "I regret to inform you that I will not be able to attend the $X $T."),
        .init(pattern: ["main", "$T", "$X", "nahi", "aa", "paungi"], professional: "I will not be able to come to the $X $T.", formal: "I regret to inform you that I will not be able to attend the $X $T."),
        .init(pattern: ["main", "$T", "nahi", "aa", "paunga"], professional: "I will not be able to come $T.", formal: "I regret to inform you that I will not be able to attend $T."),
        .init(pattern: ["main", "$T", "nahi", "aa", "paungi"], professional: "I will not be able to come $T.", formal: "I regret to inform you that I will not be able to attend $T."),
        .init(pattern: ["$T", "$X", "mein", "milte", "hain"], professional: "Let us meet at the $X $T.", formal: "I look forward to meeting you at the $X $T."),
        .init(pattern: ["$T", "milte", "hain"], professional: "Let us meet $T.", formal: "I look forward to meeting you $T."),
        .init(pattern: ["$T", "milte", "hai"], professional: "Let us meet $T.", formal: "I look forward to meeting you $T."),
        .init(pattern: ["main", "theek", "hoon"], professional: "I am doing well.", formal: "I am doing well, thank you."),
        .init(pattern: ["main", "theek", "hu"], professional: "I am doing well.", formal: "I am doing well, thank you."),
        .init(pattern: ["mujhe", "nahi", "pata"], professional: "I am not sure.", formal: "I am afraid I do not have that information."),
        .init(pattern: ["mujhe", "samajh", "nahi", "aaya"], professional: "I did not understand this.", formal: "I am afraid I did not understand this. Could you please explain?"),
        .init(pattern: ["mujhe", "ye", "samajh", "nahi", "aaya"], professional: "I did not understand this.", formal: "I am afraid I did not understand this. Could you please explain?"),
        .init(pattern: ["main", "ghar", "pahuch", "gaya"], professional: "I have reached home.", formal: "I have reached home safely."),
        .init(pattern: ["main", "ghar", "pahuch", "gayi"], professional: "I have reached home.", formal: "I have reached home safely."),
        .init(pattern: ["thoda", "wait", "karna"], professional: "Please wait a moment.", formal: "Kindly wait a moment."),
        .init(pattern: ["thoda", "wait", "karo"], professional: "Please wait a moment.", formal: "Kindly wait a moment."),
        .init(pattern: ["kya", "plan", "hai"], professional: "What is the plan?", formal: "Could you please share the plan?"),
        .init(pattern: ["$T", "kya", "plan", "hai"], professional: "What is the plan for $T?", formal: "Could you please share the plan for $T?"),
        .init(pattern: ["tum", "kahan", "ho"], professional: "Where are you?", formal: "May I know where you are?"),
        .init(pattern: ["aap", "kahan", "hain"], professional: "Where are you?", formal: "May I know where you are?"),
        .init(pattern: ["kaise", "ho"], professional: "How are you?", formal: "How are you doing?"),
        .init(pattern: ["kam", "ho", "gaya"], professional: "The work is done.", formal: "The work has been completed."),
        .init(pattern: ["kaam", "ho", "gaya"], professional: "The work is done.", formal: "The work has been completed."),
    ]

    static func match(_ text: String, lexicon: Lexicon) -> Meaning? {
        var words = Tokenizer.tokenize(text).filter { $0.kind == .word }.map { lexicon.canonical(of: $0.text) }
        // Forms of address do not change the meaning, and do not belong in a formal sentence.
        let drop: Set<String> = ["bhai", "yaar", "arre", "sir", "bro", "please"]
        words.removeAll { drop.contains($0) }
        guard !words.isEmpty else { return nil }
        for rule in rules {
            if let bindings = bind(rule.pattern, words, lexicon: lexicon) {
                return Meaning(professional: fill(rule.professional, bindings), formal: fill(rule.formal, bindings))
            }
        }
        return nil
    }

    private static func fill(_ template: String, _ bindings: [String: String]) -> String {
        var out = template
        for (key, value) in bindings { out = out.replacingOccurrences(of: key, with: value) }
        for vowel in "aeiou" { out = out.replacingOccurrences(of: " a \(vowel)", with: " an \(vowel)") }
        return out
    }

    private static func bind(_ pattern: [String], _ words: [String], lexicon: Lexicon) -> [String: String]? {
        var bindings: [String: String] = [:]
        var w = 0
        for (p, item) in pattern.enumerated() {
            switch item {
            case "$T":
                guard w < words.count, let t = time[words[w]] else { return nil }
                bindings["$T"] = t
                w += 1
            case "$X":
                // Consume until the next literal in the pattern.
                let nextLiteral = pattern[(p + 1)...].first { !$0.hasPrefix("$") }
                var collected: [String] = []
                while w < words.count, words[w] != nextLiteral {
                    guard time[words[w]] == nil else { return nil }
                    collected.append(words[w])
                    w += 1
                }
                guard !collected.isEmpty, collected.count <= 3 else { return nil }
                // English carries over unchanged and Hindi needs a known gloss. Otherwise the rule
                // does not apply, rather than producing a half-translated sentence.
                var english: [String] = []
                for word in collected {
                    guard let entry = lexicon.entry(word) else { return nil }
                    if entry.englishCount > 0 {
                        english.append(word)
                    } else if let gloss = entry.gloss, !gloss.contains("/") {
                        english.append(gloss)
                    } else {
                        return nil
                    }
                }
                bindings["$X"] = english.joined(separator: " ")
            default:
                guard w < words.count, words[w] == item else { return nil }
                w += 1
            }
        }
        return w == words.count ? bindings : nil
    }
}
