@_exported import LanguageCore
@_exported import HinglishEngine
@_exported import LanguageDetectionEngine
@_exported import TransliterationEngine
@_exported import StorageEngine
@_exported import PersonalizationEngine
@_exported import CorrectionEngine
@_exported import PredictionEngine
@_exported import AIWritingEngine
@_exported import KeyboardInputEngine
@_exported import PrivacyManager
@_exported import EmojiEngine
import Foundation

public struct Suggestion: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Keep exactly what was typed.
        case preserve
        /// A fix for a likely typo.
        case correction
        case completion
        case nextWord
        case phrase
        /// An optional better sentence: conventional spelling, punctuation or phrasing.
        case improvement
        case transliteration
        case expansion
        /// An emoji for the word just typed. It is added after the word, which stays.
        case emoji
    }

    public let kind: Kind
    /// Text shown in the bar.
    public let display: String
    /// The end of the existing text that this replaces.
    public let replacing: String
    public let insertion: String
    public let addsSpace: Bool
    /// When true, this is what would be auto-applied at the next space.
    public var willAutoApply = false

    public init(kind: Kind, display: String, replacing: String, insertion: String, addsSpace: Bool = true, willAutoApply: Bool = false) {
        self.kind = kind
        self.display = display
        self.replacing = replacing
        self.insertion = insertion
        self.addsSpace = addsSpace
        self.willAutoApply = willAutoApply
    }
}

/// The offline language brain. Composes the engines and owns no UI.
public final class BoliKeyEngine {
    public let lexicon: Lexicon
    public let hinglish: HinglishEngine
    public private(set) var detector: LanguageDetector
    public let transliterator: Transliterator
    public let personalization: PersonalizationEngine
    public let correction: CorrectionEngine
    public let prediction: PredictionEngine
    public let writing: WritingEngine
    public let emoji: EmojiLexicon
    public let store: SharedStore
    public var settings: KeyboardSettings {
        didSet { applySettings() }
    }
    public var fieldPolicy: FieldPolicy = .full

    public init(store: SharedStore, lexicon: Lexicon = .shared, settings: KeyboardSettings? = nil) {
        self.store = store
        self.lexicon = lexicon
        let loaded = settings ?? SettingsStore.load(from: store)
        self.settings = loaded
        hinglish = HinglishEngine(lexicon: lexicon)
        detector = LanguageDetector(lexicon: lexicon)
        transliterator = Transliterator(lexicon: lexicon)
        personalization = PersonalizationEngine(store: store, lexicon: lexicon)
        correction = CorrectionEngine(lexicon: lexicon, hinglish: hinglish, detector: detector, personal: personalization)
        prediction = PredictionEngine(lexicon: lexicon, detector: detector, personal: personalization)
        writing = WritingEngine(lexicon: lexicon, hinglish: hinglish)
        emoji = .shared
        applySettings()
    }

    private func applySettings() {
        personalization.isEnabled = settings.personalizationEnabled
    }

    /// Re-reads settings and personal data the app may have changed. Call when the keyboard appears.
    public func reloadFromDisk() {
        settings = SettingsStore.load(from: store)
        personalization.reload(resetGeneration: settings.resetGeneration)
    }

    private var preference: Float {
        switch settings.languageMode {
        case .hinglish: return 0.7
        case .english: return 0.05
        case .hindi: return 0.95
        }
    }

    // MARK: Correction at a word boundary

    /// The replacement to apply automatically, or nil to preserve the word.
    public func autoCorrection(for word: String, context: String) -> String? {
        guard fieldPolicy.mayAutoCorrect, settings.autoCorrectEnabled else { return nil }
        switch correction.decide(word: word, context: context, autoCorrectEnabled: true) {
        case .preserve: return nil
        case .correct(let best, _): return Self.matchCase(of: word, in: best.word)
        }
    }

    // MARK: Suggestions

    public func suggestions(before context: String) -> [Suggestion] {
        guard fieldPolicy.mayPredict, settings.predictionsEnabled else { return [] }
        let typed = Tokenizer.trailingWord(in: context)
        return typed.isEmpty ? nextWordSuggestions(context) : midWordSuggestions(typed: typed, context: context)
    }

    private func blend(_ context: String) -> PredictionEngine.Blend {
        let sentence = Tokenizer.currentSentence(in: context)
        var blend = prediction.blend(forContext: sentence, preference: preference)
        if settings.languageMode == .hindi, sentence.isEmpty { blend.devanagari = true }
        return blend
    }

    private func capitalizedIfSentenceStart(_ text: String, head: String) -> String {
        guard settings.autoCapitalizeEnabled else { return text }
        let isStart = Tokenizer.currentSentence(in: head).isEmpty
        return isStart ? text.prefix(1).uppercased() + text.dropFirst() : text
    }

    private func nextWordSuggestions(_ context: String) -> [Suggestion] {
        let b = blend(context)
        let sentence = Tokenizer.currentSentence(in: context)
        let wordCount = sentence.split(separator: " ").count
        var out: [Suggestion] = []
        var used = Set<String>()
        let words = prediction.nextWords(context: context, blend: b, limit: 4)
        // The likeliest single word comes first: it is usually all that is wanted.
        if let first = words.first {
            let text = capitalizedIfSentenceStart(first.text, head: context)
            used.insert(first.text.lowercased())
            out.append(Suggestion(kind: .nextWord, display: text, replacing: "", insertion: text))
        }
        // Two words of context are enough for a phrase to mean something.
        if wordCount >= 2 {
            for phrase in prediction.phrases(context: context, blend: b, limit: 4) where out.count < 3 && used.insert(phrase.text.lowercased()).inserted {
                out.append(Suggestion(kind: .phrase, display: phraseDisplay(sentence: sentence, continuation: phrase.text), replacing: "", insertion: phrase.text))
            }
        }
        for word in words.dropFirst() where out.count < 3 && used.insert(word.text.lowercased()).inserted {
            let text = capitalizedIfSentenceStart(word.text, head: context)
            out.append(Suggestion(kind: .nextWord, display: text, replacing: "", insertion: text))
        }
        // Right after "party ", the emoji is what comes next.
        if let last = Tokenizer.tokenize(sentence).last, last.kind == .word {
            place(emojiSuggestion(for: last.text, afterSpace: true), in: &out)
        }
        return out
    }

    private func phraseDisplay(sentence: String, continuation: String) -> String {
        let lastTwo = sentence.split(separator: " ").suffix(2).joined(separator: " ")
        // The strip has room for about 20 characters. Beyond that, only the new words matter.
        let full = "\(lastTwo) \(continuation)"
        return lastTwo.isEmpty || full.count > 20 ? continuation : full
    }

    private func midWordSuggestions(typed: String, context: String) -> [Suggestion] {
        let head = String(context.dropLast(typed.count))
        let sentence = Tokenizer.currentSentence(in: context)
        let b = blend(context)
        let isDevanagari = Script.of(typed) == .devanagari
        let decision = correction.decide(word: typed, context: head, autoCorrectEnabled: settings.autoCorrectEnabled && fieldPolicy.mayAutoCorrect)
        var out: [Suggestion] = []

        func add(_ s: Suggestion) {
            guard out.count < 3, !out.contains(where: { $0.insertion.lowercased() == s.insertion.lowercased() && $0.replacing == s.replacing }) else { return }
            out.append(s)
        }
        let preserve = Suggestion(kind: .preserve, display: "“\(typed)”", replacing: typed, insertion: typed)

        // An abbreviation the user defined is offered, never applied.
        if let expansion = personalization.entry(for: typed)?.expansion {
            add(preserve)
            add(Suggestion(kind: .expansion, display: expansion, replacing: typed, insertion: expansion))
        }

        switch decision {
        case .correct(let best, let alternatives):
            add(preserve)
            let word = Self.matchCase(of: typed, in: best.word)
            add(Suggestion(kind: .correction, display: word, replacing: typed, insertion: word, willAutoApply: true))
            for alt in alternatives { add(correctionSuggestion(alt, typed: typed)) }
        case .preserve(let reason, let candidates):
            switch reason {
            case .knownHinglish, .knownEnglish, .devanagari, .personalVocabulary:
                addKnownWordSuggestions(typed: typed, context: context, head: head, sentence: sentence, blend: b, add: add)
            case .shortForm:
                // One or two letters are the start of a word far more often than a word to keep.
                break
            default:
                add(preserve)
                for c in candidates { add(correctionSuggestion(c, typed: typed)) }
            }
        }

        // Fill what is left with completions.
        for completion in prediction.completions(prefix: typed, context: head, blend: b, limit: 4) {
            let word = Self.matchCase(of: typed, in: completion.text)
            add(Suggestion(kind: .completion, display: word, replacing: typed, insertion: word))
        }
        if settings.devanagariSuggestionsEnabled, !isDevanagari, hinglish.isHindi(typed), let last = out.indices.last, out.count == 3 {
            let deva = transliterator.toDevanagari(word: typed)
            out[last] = Suggestion(kind: .transliteration, display: deva, replacing: typed, insertion: deva)
        }
        place(emojiSuggestion(for: typed, afterSpace: false), in: &out)
        return out
    }

    // MARK: Emoji

    /// An emoji for `word`, inserted after it. The word itself is never replaced.
    private func emojiSuggestion(for word: String, afterSpace: Bool) -> Suggestion? {
        guard settings.emojiSuggestionsEnabled, !word.isEmpty else { return nil }
        let found = emoji.emoji(for: word).first ?? emoji.emoji(for: lexicon.canonical(of: word)).first
        guard let found else { return nil }
        return Suggestion(kind: .emoji, display: found, replacing: "", insertion: afterSpace ? found : " " + found)
    }

    /// An emoji takes a free slot, or the last one holding a prediction. It never pushes out the
    /// original, a correction, a better sentence, an expansion or a transliteration.
    private func place(_ suggestion: Suggestion?, in out: inout [Suggestion]) {
        guard let suggestion else { return }
        if out.count < 3 {
            out.append(suggestion)
        } else if let slot = out.lastIndex(where: { [.completion, .nextWord, .phrase].contains($0.kind) }) {
            out[slot] = suggestion
        }
    }

    /// Call when the user picks an emoji from the panel or the bar. It is kept for the panel's
    /// recent row, and only when the field allows learning.
    public func didUseEmoji(_ emoji: String) {
        guard fieldPolicy.mayLearn else { return }
        personalization.recordEmoji(emoji)
        personalization.persist()
    }

    private func correctionSuggestion(_ candidate: Candidate, typed: String) -> Suggestion {
        let word = Self.matchCase(of: typed, in: candidate.word)
        return Suggestion(kind: .correction, display: word, replacing: typed, insertion: word)
    }

    private func addKnownWordSuggestions(typed: String, context: String, head: String, sentence: String, blend b: PredictionEngine.Blend,
                                         add: (Suggestion) -> Void) {
        let wordCount = sentence.split(separator: " ").count
        // Sentence options: original first, then the optional better versions.
        if wordCount >= 3, let options = correction.sentenceOptions(for: sentence), options.normalised != nil || options.improved != nil {
            add(Suggestion(kind: .preserve, display: sentence, replacing: sentence, insertion: sentence))
            if let normalised = options.normalised {
                add(Suggestion(kind: .improvement, display: normalised, replacing: sentence, insertion: normalised))
            }
            if let improved = options.improved {
                add(Suggestion(kind: .improvement, display: improved, replacing: sentence, insertion: improved))
            }
            if let punctuated = options.punctuated {
                add(Suggestion(kind: .improvement, display: punctuated, replacing: sentence, insertion: punctuated))
            }
            return
        }
        if wordCount >= 1 {
            // "kal mil" is a word already, but "milte" is what usually comes next. Being in the middle
            // of a longer word is likelier than being done, so that gets the first slot.
            if let likely = prediction.expectedCompletion(prefix: typed, context: head, blend: b) {
                let word = Self.matchCase(of: typed, in: likely)
                add(Suggestion(kind: .completion, display: word, replacing: typed, insertion: word))
            }
            // After a single English word the sentence corpus has little to say about what comes
            // next, and the phrases read as translation exercises. Hinglish phrases hold up.
            if wordCount >= 2 || b.hinglish >= 0.5 {
                for phrase in prediction.phrases(context: context, blend: b, limit: 3) {
                    add(Suggestion(kind: .phrase, display: phraseDisplay(sentence: sentence, continuation: phrase.text), replacing: "", insertion: " " + phrase.text))
                }
            }
        }
        if let normal = hinglish.conventionalSpelling(of: typed), b.hinglish >= 0.5 {
            add(Suggestion(kind: .preserve, display: "“\(typed)”", replacing: typed, insertion: typed))
            add(Suggestion(kind: .correction, display: Self.matchCase(of: typed, in: normal), replacing: typed, insertion: Self.matchCase(of: typed, in: normal)))
        }
        // A finished word with nothing else to offer still has a likely next word.
        for next in prediction.nextWords(context: context, blend: b, limit: 3) {
            add(Suggestion(kind: .nextWord, display: next.text, replacing: "", insertion: " " + next.text))
        }
    }

    // MARK: Learning

    /// Call when the user taps a suggestion. This is the main thing the keyboard learns from.
    public func didAccept(_ suggestion: Suggestion, context: String) {
        guard fieldPolicy.mayLearn else { return }
        if suggestion.kind == .emoji {
            didUseEmoji(suggestion.display)
            return
        }
        // Whole sentences are the user's own writing. Choosing one is not a phrase worth keeping.
        if suggestion.kind == .improvement || suggestion.insertion.contains(" ") && suggestion.kind == .preserve { return }
        let head = String(context.dropLast(suggestion.replacing.count))
        let previous = Tokenizer.trailingWord(in: head.trimmingCharacters(in: .whitespaces))
        if suggestion.kind == .preserve {
            personalization.recordPreserved(word: suggestion.insertion)
        } else {
            personalization.recordAccepted(text: suggestion.insertion.trimmingCharacters(in: .whitespaces), previousWord: previous.isEmpty ? nil : previous)
        }
        personalization.persist()
    }

    public func didUndoCorrection(typed: String, corrected: String) {
        guard fieldPolicy.mayLearn else { return }
        personalization.recordRejectedCorrection(typed: typed, corrected: corrected)
        personalization.persist()
    }

    // MARK: Rewriting

    public func rewrites(of sentence: String) -> [Rewrite] {
        writing.rewrites(of: sentence)
    }

    public static func matchCase(of original: String, in replacement: String) -> String {
        guard let first = original.first, first.isUppercase else { return replacement }
        if original.count > 1, original == original.uppercased() { return replacement.uppercased() }
        return replacement.prefix(1).uppercased() + replacement.dropFirst()
    }
}
