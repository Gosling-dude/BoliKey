import XCTest
@testable import BoliKeyKit

final class EmojiTests: XCTestCase {
    let lexicon = EmojiLexicon.shared

    private func makeStore() -> SharedStore {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("bolikey-emoji-\(UUID().uuidString)")
        return SharedStore(sharedDirectory: base.appendingPathComponent("shared"), privateDirectory: base.appendingPathComponent("private"))
    }

    // MARK: The table

    func testTableIsWellFormed() {
        XCTAssertGreaterThan(lexicon.allKeywords.count, 250)
        XCTAssertEqual(Set(lexicon.allKeywords).count, lexicon.allKeywords.count, "Each keyword appears once")
        for keyword in lexicon.allKeywords {
            XCTAssertEqual(keyword, keyword.lowercased(), keyword)
            XCTAssertFalse(keyword.contains(" "), keyword)
            let emoji = lexicon.emoji(for: keyword)
            XCTAssertFalse(emoji.isEmpty, keyword)
            for e in emoji {
                XCTAssertEqual(e.count, 1, "\(keyword): \(e) must be one character")
                XCTAssertTrue(e.unicodeScalars.contains { $0.properties.isEmoji && $0.value > 0x238C }, "\(keyword): \(e) is not an emoji")
            }
        }
    }

    func testEverydayWordsHaveNoEmoji() {
        // These come up in almost every message. An emoji for each would crowd out the words.
        for word in ["hai", "ok", "haan", "nahi", "bhai", "yaar", "hi", "kaam", "call", "kya", "to", "main", "the", "and"] {
            XCTAssertTrue(lexicon.emoji(for: word).isEmpty, word)
        }
    }

    func testHinglishAndEnglishWords() {
        XCTAssertEqual(lexicon.emoji(for: "chai").first, "☕")
        XCTAssertEqual(lexicon.emoji(for: "dil").first, "❤️")
        XCTAssertEqual(lexicon.emoji(for: "pyar").first, "❤️", "A common spelling variant")
        XCTAssertEqual(lexicon.emoji(for: "Party").first, "🎉", "Case does not matter")
        XCTAssertEqual(lexicon.emoji(for: "diwali").first, "🪔")
        XCTAssertEqual(lexicon.emoji(for: "दिल").first, "❤️", "Devanagari words too")
    }

    // MARK: Search

    func testSearchFindsKeywordsAndPrefixes() {
        XCTAssertEqual(lexicon.search("chai", among: EmojiCatalog.allEmoji).first, "☕")
        XCTAssertEqual(lexicon.search("birth", among: EmojiCatalog.allEmoji).first, "🎂", "A keyword prefix")
        XCTAssertTrue(lexicon.search("gus", among: EmojiCatalog.allEmoji).contains("😡"))
    }

    func testSearchFallsBackToUnicodeNames() {
        // No keyword says "joy", but the emoji's name is "face with tears of joy".
        XCTAssertTrue(lexicon.search("joy", among: EmojiCatalog.allEmoji).contains("😂"))
        XCTAssertTrue(lexicon.search("tears joy", among: EmojiCatalog.allEmoji).contains("😂"), "Every word must match")
        XCTAssertTrue(lexicon.search("india", among: EmojiCatalog.allEmoji).contains("🇮🇳"), "Flags are found by country")
    }

    func testSearchEdgeCases() {
        XCTAssertTrue(lexicon.search("", among: EmojiCatalog.allEmoji).isEmpty)
        XCTAssertTrue(lexicon.search("   ", among: EmojiCatalog.allEmoji).isEmpty)
        XCTAssertTrue(lexicon.search("qqqzzz", among: EmojiCatalog.allEmoji).isEmpty)
        let results = lexicon.search("h", among: EmojiCatalog.allEmoji, limit: 12)
        XCTAssertLessThanOrEqual(results.count, 12)
        XCTAssertEqual(Set(results).count, results.count, "No duplicates")
    }

    func testCatalogStillHasItsCategories() {
        XCTAssertEqual(EmojiCatalog.categories.count, 7)
        XCTAssertEqual(Set(EmojiCatalog.allEmoji).count, EmojiCatalog.allEmoji.count)
        XCTAssertTrue(EmojiCatalog.allEmoji.contains("🪔"))
    }

    // MARK: Suggestions

    func testEmojiIsOfferedForTheWordBeingTyped() throws {
        let engine = makeEngine()
        let suggestions = engine.suggestions(before: "aaj party")
        let emoji = try XCTUnwrap(suggestions.first { $0.kind == .emoji }, "\(suggestions.map(\.display))")
        XCTAssertEqual(emoji.display, "🎉")
        XCTAssertEqual(emoji.replacing, "", "The word stays")
        XCTAssertLessThanOrEqual(suggestions.count, 3)
    }

    func testEmojiIsOfferedRightAfterTheWord() throws {
        let engine = makeEngine()
        let suggestions = engine.suggestions(before: "chalo chai ")
        let emoji = try XCTUnwrap(suggestions.first { $0.kind == .emoji }, "\(suggestions.map(\.display))")
        XCTAssertEqual(emoji.insertion, "☕")
        XCTAssertFalse(engine.suggestions(before: "chalo chai ☕ ").contains { $0.kind == .emoji }, "Not twice")
        XCTAssertFalse(engine.suggestions(before: "chalo chai, ").contains { $0.kind == .emoji })
    }

    func testAcceptingAnEmojiKeepsTheWord() throws {
        let engine = makeEngine()
        let harness = TypingHarness(engine: engine)
        harness.type("party")
        let emoji = try XCTUnwrap(engine.suggestions(before: harness.proxy.text).first { $0.kind == .emoji })
        harness.input.accept(replacing: emoji.replacing, with: emoji.insertion, addSpace: emoji.addsSpace)
        XCTAssertEqual(harness.proxy.text, "party 🎉 ")
    }

    func testEmojiOnlyEverTakesThePlaceOfAPrediction() {
        var off = KeyboardSettings()
        off.emojiSuggestionsEnabled = false
        let withEmoji = makeEngine()
        let without = makeEngine(settings: off)
        let predictions: [Suggestion.Kind] = [.completion, .nextWord, .phrase]
        for context in ["aaj party", "chalo chai ", "aaj mai bahut khush", "mujhe pyar", "happy birthday", "kal party hai kya party", "teh party", "mai thik hu", "teh"] {
            let on = withEmoji.suggestions(before: context)
            let plain = without.suggestions(before: context)
            for kept in plain where !predictions.contains(kept.kind) {
                XCTAssertTrue(on.contains(kept), "\(context): the emoji pushed out \(kept.display)")
            }
            XCTAssertLessThanOrEqual(on.count, 3)
            XCTAssertLessThanOrEqual(on.filter { $0.kind == .emoji }.count, 1)
        }
    }

    func testEmojiSuggestionsCanBeTurnedOff() {
        var settings = KeyboardSettings()
        settings.emojiSuggestionsEnabled = false
        let engine = makeEngine(settings: settings)
        XCTAssertFalse(engine.suggestions(before: "aaj party").contains { $0.kind == .emoji })
        XCTAssertFalse(engine.suggestions(before: "chalo chai ").contains { $0.kind == .emoji })
    }

    func testNoEmojiInSecureFields() {
        let engine = makeEngine()
        engine.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSecure: true))
        XCTAssertTrue(engine.suggestions(before: "party").isEmpty)
    }

    func testOldSettingsTurnEmojiOn() throws {
        let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(#"{"autoCorrectEnabled":false}"#.utf8))
        XCTAssertTrue(settings.emojiSuggestionsEnabled)
    }

    // MARK: Recent emoji

    func testPickedEmojiBecomeRecentNewestFirst() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        engine.didUseEmoji("😂")
        engine.didUseEmoji("☕")
        engine.didUseEmoji("😂")
        XCTAssertEqual(engine.personalization.recentEmoji, ["😂", "☕"])
        XCTAssertTrue(engine.personalization.learned.wordCounts.isEmpty, "An emoji is not a word")
    }

    func testAcceptedEmojiSuggestionIsRecentNotAWord() throws {
        let engine = makeEngine()
        let emoji = try XCTUnwrap(engine.suggestions(before: "party").first { $0.kind == .emoji })
        engine.didAccept(emoji, context: "party")
        XCTAssertEqual(engine.personalization.recentEmoji, ["🎉"])
        XCTAssertTrue(engine.personalization.learned.wordCounts.isEmpty)
        XCTAssertTrue(engine.personalization.learned.phraseCounts.isEmpty)
    }

    func testRecentEmojiAreCapped() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        for emoji in EmojiCatalog.allEmoji.prefix(40) { engine.didUseEmoji(emoji) }
        XCTAssertEqual(engine.personalization.recentEmoji.count, PersonalizationEngine.recentEmojiLimit)
        XCTAssertEqual(engine.personalization.recentEmoji.first, EmojiCatalog.allEmoji[39])
    }

    func testRecentEmojiSurviveReloadAndAreErasedByReset() {
        let store = makeStore()
        let keyboard = BoliKeyEngine(store: store, settings: KeyboardSettings())
        keyboard.didUseEmoji("🔥")
        let app = BoliKeyEngine(store: store, settings: KeyboardSettings())
        XCTAssertEqual(PrivacyManager.inventory(personal: app.personalization).first { $0.id == "emoji" }?.count, 1)
        app.personalization.resetLearning(generation: 1)
        keyboard.personalization.reload(resetGeneration: 1)
        XCTAssertTrue(keyboard.personalization.recentEmoji.isEmpty)
    }

    func testNothingIsRememberedWhenLearningIsOffOrNotAllowed() {
        var settings = KeyboardSettings()
        settings.personalizationEnabled = false
        let off = BoliKeyEngine(store: makeStore(), settings: settings)
        off.didUseEmoji("🔥")
        XCTAssertTrue(off.personalization.learned.recentEmoji.isEmpty)

        let secure = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        secure.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSensitiveKind: true))
        secure.didUseEmoji("🔥")
        XCTAssertTrue(secure.personalization.learned.recentEmoji.isEmpty)
    }

    func testLearnedFilesWithoutRecentEmojiStillLoad() throws {
        let json = #"{"wordCounts":{"kal":2},"bigramCounts":{},"phraseCounts":{},"rejectedCorrections":[],"preferredSpellings":{},"resetGeneration":3}"#
        let learned = try JSONDecoder().decode(LearnedData.self, from: Data(json.utf8))
        XCTAssertEqual(learned.wordCounts["kal"], 2)
        XCTAssertEqual(learned.resetGeneration, 3)
        XCTAssertTrue(learned.recentEmoji.isEmpty)
    }
}
