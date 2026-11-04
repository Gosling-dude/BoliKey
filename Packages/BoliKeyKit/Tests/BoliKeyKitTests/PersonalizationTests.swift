import XCTest
@testable import BoliKeyKit

final class PersonalizationTests: XCTestCase {
    private func makeStore() -> SharedStore {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("bolikey-p-\(UUID().uuidString)")
        return SharedStore(sharedDirectory: base.appendingPathComponent("shared"), privateDirectory: base.appendingPathComponent("private"))
    }

    func testDictionaryPersistsAndPowersCompletion() {
        let store = makeStore()
        let engine = BoliKeyEngine(store: store, settings: KeyboardSettings())
        engine.personalization.add(VocabularyEntry(text: "Chintu", kind: .nickname))
        XCTAssertTrue(engine.suggestions(before: "Chin").contains { $0.insertion == "Chintu" })
        let reopened = BoliKeyEngine(store: store, settings: KeyboardSettings())
        XCTAssertTrue(reopened.personalization.isPersonalWord("chintu"))
        reopened.personalization.remove(VocabularyEntry(text: "Chintu", kind: .nickname))
        XCTAssertFalse(BoliKeyEngine(store: store, settings: KeyboardSettings()).personalization.isPersonalWord("chintu"))
    }

    func testAbbreviationExpansionIsOfferedNeverApplied() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        engine.personalization.add(VocabularyEntry(text: "omw", kind: .abbreviation, expansion: "on my way"))
        XCTAssertTrue(engine.suggestions(before: "omw").contains { $0.insertion == "on my way" && $0.kind == .expansion })
        XCTAssertNil(engine.autoCorrection(for: "omw", context: ""))
    }

    func testAcceptedSuggestionsAreLearned() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        let s = Suggestion(kind: .nextWord, display: "dosto", replacing: "", insertion: "dosto")
        for _ in 0..<3 { engine.didAccept(s, context: "kya haal hai ") }
        XCTAssertEqual(engine.personalization.usage(of: "dosto"), 3)
        let next = engine.prediction.nextWords(context: "hai ", blend: .init(hinglish: 0.9, english: 0.1), limit: 3).map(\.text)
        XCTAssertTrue(next.contains("dosto"), "\(next)")
    }

    func testPreferredSpellingIsUsedInPrediction() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        engine.didAccept(Suggestion(kind: .completion, display: "nhi", replacing: "", insertion: "nhi"), context: "")
        XCTAssertEqual(engine.personalization.preferredSpelling(of: "nahi"), "nhi")
        let next = engine.prediction.nextWords(context: "mujhe ", blend: .init(hinglish: 0.95, english: 0.05), limit: 8).map(\.text)
        XCTAssertFalse(next.contains("nahi"), "\(next)")
    }

    func testTypingWithoutChoosingLearnsNothing() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        let harness = TypingHarness(engine: engine)
        harness.type("my secret plan is here ")
        XCTAssertTrue(engine.personalization.learned.isEmpty, "Plain typing must never be stored")
    }

    func testDisablingPersonalizationStopsLearningAndUse() {
        var settings = KeyboardSettings()
        settings.personalizationEnabled = false
        let engine = BoliKeyEngine(store: makeStore(), settings: settings)
        engine.didAccept(Suggestion(kind: .nextWord, display: "dosto", replacing: "", insertion: "dosto"), context: "hai ")
        XCTAssertEqual(engine.personalization.learned.wordCounts.count, 0)
    }

    func testResetLearningKeepsDictionaryAndClearAllDoesNot() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        engine.personalization.add(VocabularyEntry(text: "Chintu", kind: .nickname))
        engine.personalization.recordPreserved(word: "gharwale")
        engine.personalization.resetLearning(generation: 1)
        XCTAssertTrue(engine.personalization.learned.isEmpty)
        XCTAssertTrue(engine.personalization.isPersonalWord("chintu"))
        engine.personalization.clearAll(generation: 2)
        XCTAssertFalse(engine.personalization.isPersonalWord("chintu"))
    }

    func testKeyboardWithReadOnlySharedContainerFallsBackToPrivateStorage() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("bolikey-ro-\(UUID().uuidString)")
        let shared = base.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        // The app writes while the keyboard, without Full Access, cannot.
        let appStore = SharedStore(sharedDirectory: shared, privateDirectory: base.appendingPathComponent("app"))
        BoliKeyEngine(store: appStore, settings: KeyboardSettings()).personalization.add(VocabularyEntry(text: "Chintu", kind: .nickname))
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: shared.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: shared.path) }

        let keyboardStore = SharedStore(sharedDirectory: shared, privateDirectory: base.appendingPathComponent("kb"))
        XCTAssertFalse(keyboardStore.canWriteShared())
        let keyboard = BoliKeyEngine(store: keyboardStore, settings: KeyboardSettings())
        XCTAssertTrue(keyboard.personalization.isPersonalWord("chintu"), "Dictionary must be readable")
        keyboard.didAccept(Suggestion(kind: .nextWord, display: "dosto", replacing: "", insertion: "dosto"), context: "")
        let reopened = BoliKeyEngine(store: keyboardStore, settings: KeyboardSettings())
        XCTAssertEqual(reopened.personalization.usage(of: "dosto"), 1)
    }

    func testAppRequestedResetReachesPrivateKeyboardData() {
        let store = makeStore()
        let keyboard = BoliKeyEngine(store: store, settings: KeyboardSettings())
        keyboard.personalization.recordPreserved(word: "gharwale")
        keyboard.personalization.persist()
        keyboard.personalization.reload(resetGeneration: 5)
        XCTAssertTrue(keyboard.personalization.learned.isEmpty)
    }

    func testPrivacyInventoryCountsMatch() {
        let engine = BoliKeyEngine(store: makeStore(), settings: KeyboardSettings())
        engine.personalization.add(VocabularyEntry(text: "Chintu", kind: .nickname))
        let items = PrivacyManager.inventory(personal: engine.personalization)
        XCTAssertEqual(items.first { $0.id == "dictionary" }?.count, 1)
        XCTAssertEqual(items.first { $0.id == "words" }?.count, 0)
    }

    func testOldSettingsFilesStillDecode() throws {
        let settings = try JSONDecoder().decode(KeyboardSettings.self, from: Data(#"{"autoCorrectEnabled":false}"#.utf8))
        XCTAssertFalse(settings.autoCorrectEnabled)
        XCTAssertEqual(settings.languageMode, .hinglish)
    }
}
