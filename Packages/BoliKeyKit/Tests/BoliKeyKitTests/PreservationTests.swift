import XCTest
@testable import BoliKeyKit

/// The product's core promise: nothing intentional is changed.
final class PreservationTests: XCTestCase {
    let engine = makeEngine()

    /// Types a sentence through the real input controller, including boundary correction.
    private func type(_ sentence: String, engine: BoliKeyEngine? = nil) -> String {
        let harness = TypingHarness(engine: engine ?? self.engine)
        harness.type(sentence)
        return harness.proxy.text
    }

    func testHinglishSentencesAreNeverChanged() {
        for sentence in ["mai thik hu", "kal milte hai", "kya kr rha hai", "mujhe nahi pta", "bhai kya scene hai", "mai ghar pahuch gya",
                         "aaj mood nahi hai", "thoda wait krna", "kya chal raha h", "tum kaha ho", "bhai mai kal office nahi aa paunga",
                         "bhai kal milte hai", "Mujhe ye samajh nahi aaya", "kya bakwas hai yaar", "chal theek h"] {
            XCTAssertEqual(type(sentence + " "), sentence + " ", sentence)
        }
    }

    func testMixedSentencesAreNeverChanged() {
        for sentence in ["I will come kal.", "Meeting 5 baje hai.", "I am ghar par.", "Let's milte tomorrow.", "I will come kal around 8 baje."] {
            XCTAssertEqual(type(sentence + " "), sentence + " ", sentence)
        }
    }

    func testEnglishSentencesAreNeverChanged() {
        for sentence in ["I am going to the office.", "Can we meet tomorrow?", "I will call you later."] {
            XCTAssertEqual(type(sentence + " "), sentence + " ", sentence)
        }
    }

    func testDevanagariIsNeverChanged() {
        for sentence in ["मैं ठीक हूँ।", "कल मिलते हैं।", "क्या कर रहे हो?"] {
            XCTAssertEqual(type(sentence + " "), sentence + " ", sentence)
        }
    }

    func testNoTranslationEverAppliesAutomatically() {
        let typed = type("bhai mai kal office nahi aa paunga ")
        XCTAssertFalse(typed.lowercased().contains("brother"))
        XCTAssertFalse(typed.lowercased().contains("tomorrow"))
    }

    func testExpressiveAndSymbolicInputIsPreserved() {
        for word in ["bhaaaai", "yaarrrr", "nooooo", "iPhone", "NASA", "@sumit", "#bolikey", "bolikey.com", "8pm", "k", "np"] {
            XCTAssertEqual(type(word + " "), word + " ", word)
        }
    }

    func testUnknownHindiLikeWordsArePreserved() {
        for word in ["pahuchgya", "thikthak", "gharwale", "dekhlena"] {
            XCTAssertEqual(type(word + " "), word + " ", word)
        }
    }

    func testGenuineTyposAreCorrected() {
        for (typo, fixed) in [("teh", "the"), ("becuase", "because"), ("definately", "definitely"), ("thnaks", "thanks"), ("bhia", "bhai"), ("tomorow", "tomorrow")] {
            XCTAssertEqual(type(typo + " "), fixed + " ", typo)
        }
    }

    func testCorrectionKeepsCapitalisation() {
        XCTAssertEqual(type("Teh "), "The ")
    }

    func testDisablingAutoCorrectStopsAllChanges() {
        var settings = KeyboardSettings()
        settings.autoCorrectEnabled = false
        let off = makeEngine(settings: settings)
        XCTAssertEqual(type("teh ", engine: off), "teh ")
        XCTAssertEqual(type("becuase ", engine: off), "becuase ")
    }

    func testBackspaceUndoesCorrectionAndItStaysUndone() {
        let harness = TypingHarness(engine: engine)
        harness.type("teh ")
        XCTAssertEqual(harness.proxy.text, "the ")
        harness.input.tapBackspace()
        XCTAssertEqual(harness.proxy.text, "teh")
        harness.type(" teh ")
        XCTAssertEqual(harness.proxy.text, "teh teh ", "A rejected correction must not come back")
    }

    func testPersonalWordsAreNeverCorrected() {
        engine.personalization.add(VocabularyEntry(text: "Thnaks", kind: .nickname))
        XCTAssertEqual(type("thnaks "), "thnaks ")
    }

    func testSecureFieldsNeverCorrectOrSuggest() {
        let e = makeEngine()
        e.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSecure: true))
        XCTAssertNil(e.autoCorrection(for: "teh", context: ""))
        XCTAssertTrue(e.suggestions(before: "kal ").isEmpty)
    }

    func testProfanityIsRecognisedButNeverProposed() {
        XCTAssertEqual(type("chutiya "), "chutiya ")
        let all = engine.suggestions(before: "chut").map(\.insertion) + engine.suggestions(before: "fuc").map(\.insertion)
        XCTAssertFalse(all.contains { ["chutiya", "fuck", "fucking"].contains($0.lowercased()) }, "\(all)")
    }
}

/// Connects the input controller to the engine exactly as the keyboard does.
final class TypingHarness: WordBoundaryDelegate {
    let proxy = StringTextProxy()
    let input: InputController
    let engine: BoliKeyEngine

    init(engine: BoliKeyEngine) {
        self.engine = engine
        input = InputController(proxy: proxy)
        input.configuration.autoCapitalizeEnabled = false
        input.delegate = self
    }

    func type(_ text: String) {
        for ch in text {
            if ch == " " {
                input.tapSpace()
            } else if ch == "\n" {
                input.tapReturn()
            } else {
                input.insertCharacter(String(ch), respectingShift: false)
            }
            input.now = { [t = input.now()] in t + 1 }
        }
    }

    func correction(for word: String, context: String) -> String? { engine.autoCorrection(for: word, context: context) }
    func didUndoCorrection(typed: String, corrected: String) { engine.didUndoCorrection(typed: typed, corrected: corrected) }
}
