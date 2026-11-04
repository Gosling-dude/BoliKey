import XCTest
@testable import BoliKeyKit

final class SuggestionTests: XCTestCase {
    let engine = makeEngine()

    func testPreservationFirstOptionsForMaiThikHu() {
        let s = engine.suggestions(before: "mai thik hu")
        XCTAssertEqual(s.map(\.display), ["mai thik hu", "main theek hu", "main bilkul theek hu"])
        XCTAssertEqual(s.first?.kind, .preserve)
        XCTAssertTrue(s.allSatisfy { !$0.willAutoApply })
    }

    func testOfficeSentenceOffersOriginalAndConventional() {
        let display = engine.suggestions(before: "bhai mai kal office nahi aa paunga").map(\.display)
        XCTAssertEqual(display.first, "bhai mai kal office nahi aa paunga")
        XCTAssertTrue(display.contains("bhai main kal office nahi aa paunga"), "\(display)")
        XCTAssertFalse(display.joined().lowercased().contains("brother"))
    }

    func testPhrasePredictionForKalKya() {
        let display = engine.suggestions(before: "kal kya").map(\.display)
        XCTAssertEqual(Set(display), ["kal kya plan hai", "kal kya scene hai", "kal kya karna hai"])
    }

    func testPhraseAcceptanceProducesTheSentence() {
        let harness = TypingHarness(engine: engine)
        harness.type("kal kya")
        let s = engine.suggestions(before: harness.proxy.text).first { $0.display == "kal kya plan hai" }
        let suggestion = try! XCTUnwrap(s)
        harness.input.accept(replacing: suggestion.replacing, with: suggestion.insertion, addSpace: suggestion.addsSpace)
        XCTAssertEqual(harness.proxy.text, "kal kya plan hai ")
    }

    func testNextWordPredictionHinglish() {
        let words = engine.suggestions(before: "bhai kal ").flatMap { $0.insertion.split(separator: " ").prefix(1).map(String.init) }
        XCTAssertFalse(words.isEmpty)
        XCTAssertEqual(engine.suggestions(before: "bhai kal ").count, 3)
        let next = engine.prediction.nextWords(context: "kya ", blend: .init(hinglish: 0.9, english: 0.1), limit: 8).map(\.text)
        XCTAssertTrue(next.contains("kar") || next.contains("hua") || next.contains("hai"), "\(next)")
    }

    func testNextWordPredictionEnglish() {
        var settings = KeyboardSettings()
        settings.languageMode = .english
        let e = makeEngine(settings: settings)
        let next = e.prediction.nextWords(context: "I am going ", blend: .init(hinglish: 0.05, english: 0.95), limit: 5).map(\.text)
        XCTAssertTrue(next.contains("to"), "\(next)")
        XCTAssertEqual(e.suggestions(before: "Can we ").count, 3)
    }

    func testPredictionUsesNormalisedContext() {
        // Different spellings of the same words reach the same statistics.
        let a = engine.prediction.nextWords(context: "kya kr rha ", blend: .init(hinglish: 0.9, english: 0.1)).map(\.text)
        let b = engine.prediction.nextWords(context: "kya kar raha ", blend: .init(hinglish: 0.9, english: 0.1)).map(\.text)
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    func testWordCompletion() {
        let c = engine.prediction.completions(prefix: "mil", context: "kal ", blend: .init(hinglish: 0.9, english: 0.1), limit: 3).map(\.text)
        XCTAssertTrue(c.contains("milte"), "\(c)")
        let d = engine.prediction.completions(prefix: "tomo", context: "see you ", blend: .init(hinglish: 0.1, english: 0.9), limit: 3).map(\.text)
        XCTAssertTrue(d.contains("tomorrow"), "\(d)")
    }

    func testTypoShowsOriginalFirstAndMarksTheFix() {
        let s = engine.suggestions(before: "teh")
        XCTAssertEqual(s.first?.kind, .preserve)
        XCTAssertEqual(s.first?.insertion, "teh")
        XCTAssertTrue(s.contains { $0.insertion == "the" && $0.willAutoApply }, "\(s)")
    }

    func testUnknownWordCanBeKept() {
        let s = engine.suggestions(before: "gharwale")
        XCTAssertEqual(s.first?.kind, .preserve)
    }

    func testDevanagariPrediction() {
        XCTAssertFalse(engine.suggestions(before: "क्या ").isEmpty)
        let c = engine.suggestions(before: "क्या क")
        XCTAssertFalse(c.isEmpty)
        XCTAssertTrue(c.allSatisfy { Script.of($0.insertion) == .devanagari }, "\(c.map(\.insertion))")
    }

    func testSuggestionsAreDisabledBySetting() {
        var settings = KeyboardSettings()
        settings.predictionsEnabled = false
        XCTAssertTrue(makeEngine(settings: settings).suggestions(before: "kal ").isEmpty)
    }

    func testOfflineModelLoaded() {
        XCTAssertGreaterThan(Lexicon.shared.entries.count, 40_000)
        XCTAssertGreaterThan(Lexicon.shared.latinTrie.count, 30_000)
    }
}

final class SentenceStartTests: XCTestCase {
    func testHinglishModeStartsWithHinglish() {
        let words = makeEngine().suggestions(before: "").map { $0.insertion.lowercased() }
        XCTAssertEqual(words.count, 3)
        XCTAssertFalse(words.contains("i"), "\(words)")
        XCTAssertTrue(words.contains { Lexicon.shared.entry($0)?.flags.contains(.hinglish) == true }, "\(words)")
    }
    func testEnglishModeStartsWithEnglish() {
        var settings = KeyboardSettings()
        settings.languageMode = .english
        XCTAssertTrue(makeEngine(settings: settings).suggestions(before: "").map(\.insertion).contains("I"))
    }
}
