import XCTest
@testable import BoliKeyKit

final class LanguageDetectionTests: XCTestCase {
    let detector = LanguageDetector()

    private func tags(_ text: String) -> [String: LanguageTag] {
        Dictionary(detector.analyze(text).tokens.filter { $0.token.kind == .word }.map { ($0.token.lowered, $0.language) }, uniquingKeysWith: { a, _ in a })
    }

    func testHinglishSentencesAreHindi() {
        for sentence in ["mai thik hu", "kal milte hai", "kya kr rha hai", "bhai kya scene hai", "mujhe nahi pta",
                         "mai ghar pahuch gya", "kya chal raha h", "tum kaha ho", "bhai mai kal office nahi aa paunga"] {
            let analysis = detector.analyze(sentence)
            XCTAssertEqual(analysis.dominant, .hindiRoman, sentence)
            XCTAssertGreaterThanOrEqual(analysis.hindiShare, 0.75, sentence)
        }
    }

    func testEnglishSentencesAreEnglish() {
        for sentence in ["I am going to the office", "Can we meet tomorrow?", "I will call you later", "the main reason is that we are late", "do you know him"] {
            let analysis = detector.analyze(sentence)
            XCTAssertEqual(analysis.dominant, .english, sentence)
            XCTAssertEqual(analysis.hindiShare, 0, sentence)
        }
    }

    func testCodeSwitchingIsTaggedPerToken() {
        let a = tags("I will come kal around 8 baje")
        XCTAssertEqual(a["i"], .english)
        XCTAssertEqual(a["come"], .english)
        XCTAssertEqual(a["kal"], .hindiRoman)
        XCTAssertEqual(a["baje"], .hindiRoman)
        XCTAssertTrue(detector.analyze("I will come kal around 8 baje").isCodeSwitched)

        XCTAssertEqual(tags("Meeting 5 baje hai")["baje"], .hindiRoman)
        XCTAssertEqual(tags("I am ghar par")["ghar"], .hindiRoman)
        XCTAssertEqual(tags("I am ghar par")["am"], .english)
        XCTAssertEqual(tags("Let's milte tomorrow")["milte"], .hindiRoman)
        XCTAssertEqual(tags("Let's milte tomorrow")["tomorrow"], .english)
    }

    func testAmbiguousWordsUseContext() {
        XCTAssertEqual(tags("going to the office")["the"], .english)
        XCTAssertEqual(tags("kal tum wahan the")["the"], .hindiRoman)
        XCTAssertEqual(tags("main ghar ja raha hoon")["main"], .hindiRoman)
    }

    func testDevanagariIsIdentifiedByScript() {
        for sentence in ["मैं ठीक हूँ।", "कल मिलते हैं।", "क्या कर रहे हो?"] {
            let analysis = detector.analyze(sentence)
            XCTAssertEqual(analysis.dominant, .hindiDevanagari, sentence)
        }
    }

    func testUnknownHindiWordsFallBackToCharacterStatistics() {
        XCTAssertEqual(tags("pahuchgya")["pahuchgya"], .hindiRoman)
        XCTAssertEqual(tags("thoughtfulness")["thoughtfulness"], .english)
    }

    func testOtherScriptsAreRecognisedForFuturePacks() {
        XCTAssertEqual(Script.of("ਪੰਜਾਬੀ"), .gurmukhi)
        XCTAssertEqual(Script.of("বাংলা"), .bengali)
        XCTAssertEqual(Script.of("தமிழ்"), .tamil)
        XCTAssertEqual(detector.analyze("ਪੰਜਾਬੀ").tokens.first?.language, .other)
    }
}
