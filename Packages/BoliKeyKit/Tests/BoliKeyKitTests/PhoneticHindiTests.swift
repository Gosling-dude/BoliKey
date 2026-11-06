import XCTest
@testable import BoliKeyKit

final class PhoneticHindiTests: XCTestCase {
    let phonetic = PhoneticHindi(lexicon: .shared)

    private func phoneticSettings() -> KeyboardSettings {
        var s = KeyboardSettings()
        s.languageMode = .hindi
        s.phoneticHindiEnabled = true
        return s
    }

    private func makeStore() -> SharedStore {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("bolikey-phonetic-\(UUID().uuidString)")
        return SharedStore(sharedDirectory: base.appendingPathComponent("shared"), privateDirectory: base.appendingPathComponent("private"))
    }

    // MARK: Converting words

    func testAuthoredWordsUseTheLexicon() {
        XCTAssertEqual(phonetic.conversion(of: "namaste"), "नमस्ते")
        XCTAssertEqual(phonetic.conversion(of: "kya"), "क्या")
        XCTAssertEqual(phonetic.conversion(of: "nhi"), "नहीं", "A spelling variant")
        XCTAssertEqual(phonetic.conversion(of: "Main"), "मैं", "Case does not matter")
        XCTAssertEqual(phonetic.conversion(of: "pyaaaar"), "प्यार", "Elongation")
    }

    func testWordsTheLexiconLacksAreFoundInHindiText() {
        // None of these has an authored spelling. Each is spelled several ways and the one real
        // Hindi text uses wins.
        let expected = ["bharat": "भारत", "dosti": "दोस्ती", "bachpan": "बचपन", "aasman": "आसमान", "rang": "रंग",
                        "gyan": "ज्ञान", "sita": "सीता", "rahul": "राहुल", "dhanyavaad": "धन्यवाद", "larka": "लड़का"]
        for (roman, deva) in expected {
            XCTAssertEqual(phonetic.conversion(of: roman), deva.precomposedStringWithCanonicalMapping, roman)
        }
    }

    func testNuktaLettersMatchHowTheVocabularyWritesThem() throws {
        let pahad = try XCTUnwrap(phonetic.conversion(of: "pahad"))
        XCTAssertEqual(Array(pahad.unicodeScalars), Array("\u{092A}\u{0939}\u{093E}\u{0921}\u{093C}".unicodeScalars), "ड़ written as ड and a nukta")
    }

    func testUnknownWordsGetTheRegularSpelling() throws {
        let word = try XCTUnwrap(phonetic.conversion(of: "bolikey"))
        XCTAssertTrue(word.unicodeScalars.allSatisfy { (0x0900...0x097F).contains($0.value) }, word)
        XCTAssertEqual(phonetic.candidates(for: "bolikey").count, 2, "Two spellings to choose from")
    }

    func testEnglishAndAbbreviationsStayAsTyped() {
        for word in ["ok", "please", "hello", "jungle", "data", "bus", "rs", "tv", "pm"] {
            XCTAssertNil(phonetic.conversion(of: word), word)
        }
        XCTAssertEqual(phonetic.conversion(of: "is"), "इस", "Its plainest reading is Hindi")
    }

    func testOnlyEnglishLettersAreConverted() {
        XCTAssertTrue(PhoneticHindi.isRoman("Namaste"))
        for word in ["", "नमस्ते", "500", "kal5", "e-mail", "café"] {
            XCTAssertFalse(PhoneticHindi.isRoman(word), word)
            XCTAssertNil(phonetic.conversion(of: word), word)
        }
    }

    func testCandidatesAndCompletions() {
        XCTAssertEqual(phonetic.candidates(for: "khana").first, "खाना")
        XCTAssertTrue(phonetic.completions(of: "namas").contains("नमस्ते"))
        XCTAssertTrue(phonetic.completions(of: "n").isEmpty, "Too short to guess")
    }

    func testConversionIsFastEnoughToRunOnEveryKey() {
        let words = ["namaste", "bharat", "dosti", "bachpan", "aasman", "zindagi", "dhanyavaad", "ghoomna", "barsaat", "insaan", "bolikey", "pardesi"]
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            for w in words {
                _ = phonetic.conversion(of: w)
                _ = phonetic.candidates(for: w)
            }
        }
        let mean = (CFAbsoluteTimeGetCurrent() - start) / Double(words.count * 10) * 1000
        print("phonetic Hindi: mean \(String(format: "%.2f", mean)) ms per word")
        XCTAssertLessThan(mean, 8, "Well inside one frame")
    }

    // MARK: Typing

    func testTypingASentence() {
        let engine = makeEngine(settings: phoneticSettings())
        let harness = TypingHarness(engine: engine)
        harness.type("mai kal ghar ja rha hu ")
        XCTAssertEqual(harness.proxy.text, "मैं कल घर जा रहा हूँ ")
    }

    func testEnglishWordsAndNumbersInAHindiSentence() {
        let engine = makeEngine(settings: phoneticSettings())
        let harness = TypingHarness(engine: engine)
        harness.type("ok bhai meeting 5 baje hai ")
        XCTAssertEqual(harness.proxy.text, "ok भाई मीटिंग 5 बजे है ")
    }

    func testFullStopAfterHindiIsADanda() {
        let engine = makeEngine(settings: phoneticSettings())
        let harness = TypingHarness(engine: engine)
        harness.input.configuration.dandaAfterDevanagari = true
        harness.type("kal milte hai.")
        XCTAssertEqual(harness.proxy.text, "कल मिलते है।")
        harness.input.tapBackspace()
        XCTAssertEqual(harness.proxy.text, "कल मिलते hai", "One backspace still brings back what was typed")

        let numbers = TypingHarness(engine: engine)
        numbers.input.configuration.dandaAfterDevanagari = true
        numbers.type("1.5 ")
        XCTAssertEqual(numbers.proxy.text, "1.5 ", "A decimal point is not a danda")
    }

    func testDoubleSpaceAfterHindiIsADanda() {
        let proxy = StringTextProxy("कल मिलते हैं")
        let input = InputController(proxy: proxy)
        input.configuration.dandaAfterDevanagari = true
        var clock: TimeInterval = 100
        input.now = { clock }
        input.tapSpace()
        clock += 0.2
        input.tapSpace()
        XCTAssertEqual(proxy.text, "कल मिलते हैं। ")
    }

    func testBackspaceUndoesAndTheWordStaysAsTypedNextTime() {
        let engine = makeEngine(settings: phoneticSettings())
        let harness = TypingHarness(engine: engine)
        harness.type("namaste ")
        XCTAssertEqual(harness.proxy.text, "नमस्ते ")
        harness.input.tapBackspace()
        XCTAssertEqual(harness.proxy.text, "namaste")
        harness.type(" namaste ")
        XCTAssertEqual(harness.proxy.text, "namaste namaste ", "An undone conversion is not repeated")
    }

    func testTheBarOffersTheOriginalAndWhatItWillBecome() throws {
        let engine = makeEngine(settings: phoneticSettings())
        let s = engine.suggestions(before: "kal namaste")
        XCTAssertEqual(s.first?.display, "“namaste”")
        let target = try XCTUnwrap(s.first { $0.willAutoApply })
        XCTAssertEqual(target.insertion, "नमस्ते")
        XCTAssertEqual(target.kind, .transliteration)
        XCTAssertFalse(engine.suggestions(before: "kal ok").contains { $0.willAutoApply }, "English stays English")
    }

    func testPickingASpellingIsRemembered() throws {
        let engine = makeEngine(settings: phoneticSettings())
        let other = try XCTUnwrap(engine.suggestions(before: "sita").first { $0.kind == .transliteration && !$0.willAutoApply })
        engine.didAccept(other, context: "sita")
        XCTAssertEqual(engine.hindiSpelling(for: "sita"), other.insertion)

        let keep = try XCTUnwrap(engine.suggestions(before: "bharat").first { $0.kind == .preserve })
        engine.didAccept(keep, context: "bharat")
        XCTAssertNil(engine.hindiSpelling(for: "bharat"), "Kept in English letters from now on")
        let items = PrivacyManager.inventory(personal: engine.personalization)
        XCTAssertEqual(items.first { $0.id == "hindi" }?.count, 2)
    }

    func testNothingIsRememberedWhenLearningIsOff() throws {
        var settings = phoneticSettings()
        settings.personalizationEnabled = false
        let engine = makeEngine(settings: settings)
        let keep = try XCTUnwrap(engine.suggestions(before: "bharat").first { $0.kind == .preserve })
        engine.didAccept(keep, context: "bharat")
        XCTAssertEqual(engine.hindiSpelling(for: "bharat"), "भारत")
        XCTAssertTrue(engine.personalization.learned.hindiSpellings.isEmpty)
    }

    func testOnlyInHindiWithTheSettingOn() {
        for settings in [KeyboardSettings(), { var s = KeyboardSettings(); s.phoneticHindiEnabled = true; return s }(),
                         { var s = KeyboardSettings(); s.languageMode = .hindi; return s }()] {
            let harness = TypingHarness(engine: makeEngine(settings: settings))
            harness.type("namaste ")
            XCTAssertEqual(harness.proxy.text, "namaste ")
        }
    }

    func testTheTypoSettingDoesNotTurnItOff() {
        var settings = phoneticSettings()
        settings.autoCorrectEnabled = false
        let harness = TypingHarness(engine: makeEngine(settings: settings))
        harness.type("namaste ")
        XCTAssertEqual(harness.proxy.text, "नमस्ते ")
    }

    func testFieldsWithoutLanguageAreLeftAlone() {
        let engine = makeEngine(settings: phoneticSettings())
        engine.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSensitiveKind: true))
        XCTAssertNil(engine.autoCorrection(for: "namaste", context: ""))
        engine.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSecure: true))
        XCTAssertNil(engine.autoCorrection(for: "namaste", context: ""))
    }

    // MARK: Stored data

    func testResetErasesTheChoices() {
        let store = makeStore()
        let engine = BoliKeyEngine(store: store, settings: phoneticSettings())
        engine.personalization.recordHindiSpelling(roman: "sita", choice: "सीता")
        engine.personalization.persist()
        engine.personalization.resetLearning(generation: 1)
        XCTAssertTrue(engine.personalization.learned.hindiSpellings.isEmpty)
    }

    func testOlderFilesStillDecode() throws {
        let json = #"{"wordCounts":{"kal":2},"bigramCounts":{},"phraseCounts":{},"rejectedCorrections":[],"preferredSpellings":{},"resetGeneration":1}"#
        let learned = try JSONDecoder().decode(LearnedData.self, from: Data(json.utf8))
        XCTAssertEqual(learned.wordCounts["kal"], 2)
        XCTAssertTrue(learned.hindiSpellings.isEmpty)
        let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(#"{"languageMode":"hindi"}"#.utf8))
        XCTAssertFalse(settings.phoneticHindiEnabled, "Off unless chosen")
    }
}
