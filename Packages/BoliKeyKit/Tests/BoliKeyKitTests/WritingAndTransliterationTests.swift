import XCTest
@testable import BoliKeyKit

final class WritingAndTransliterationTests: XCTestCase {
    let engine = makeEngine()

    private func style(_ text: String, _ style: WritingStyle) -> Rewrite { engine.writing.rewrite(text, style: style)! }

    func testSpecExampleKalMeetingHaiKya() {
        XCTAssertEqual(style("kal meeting hai kya", .casual).text, "kal meeting hai kya?")
        XCTAssertEqual(style("kal meeting hai kya", .professional).text, "Is there a meeting scheduled for tomorrow?")
        XCTAssertEqual(style("kal meeting hai kya", .friendly).text, "Hey, kal meeting hai kya?")
        XCTAssertEqual(style("kal meeting hai kya", .professional).method, .pattern)
    }

    func testAllSixStylesProduceText() {
        XCTAssertEqual(engine.rewrites(of: "bhai kal milte hai").count, 6)
    }

    func testVariantSpellingsReachTheSamePatterns() {
        XCTAssertEqual(style("mai thik hu", .professional).text, "I am doing well.")
        XCTAssertEqual(style("mujhe nahi pta", .professional).text, "I am not sure.")
        XCTAssertEqual(style("bhai kal milte hai", .professional).text, "Let us meet tomorrow.")
    }

    func testHindiNounsTranslateThroughGloss() {
        XCTAssertEqual(style("kal chutti hai kya", .professional).text, "Is there a holiday scheduled for tomorrow?")
    }

    func testUnknownPatternIsNeverFakeTranslated() {
        let r = style("bhai yeh gaana mast hai", .professional)
        XCTAssertEqual(r.method, .polish)
        XCTAssertTrue(r.text.lowercased().contains("gaana"), r.text)
    }

    func testEnglishPolish() {
        XCTAssertEqual(style("i can't come tmrw", .formal).text, "I cannot come tomorrow.")
        XCTAssertEqual(style("gonna be late", .professional).text, "Going to be late.")
    }

    func testShortRemovesFillerOnly() {
        XCTAssertEqual(style("bhai actually kal meeting hai", .short).text, "kal meeting hai")
    }

    func testPlayfulAddsTone() {
        XCTAssertTrue(style("chalo chalte hain", .playful).text.hasSuffix("😄"))
    }

    func testEmptyTextProducesNothing() {
        XCTAssertNil(engine.writing.rewrite("  ", style: .formal))
    }

    func testTransliterationOfKnownWords() {
        XCTAssertEqual(engine.transliterator.toDevanagari(word: "kya"), "क्या")
        XCTAssertEqual(engine.transliterator.toDevanagari(word: "thik"), "ठीक")
        XCTAssertEqual(engine.transliterator.toDevanagari(sentence: "main theek hoon."), "मैं ठीक हूँ।")
    }

    func testTransliterationRulesForUnknownWords() {
        XCTAssertEqual(Transliterator.ruleBased("namak"), "नमक")
        XCTAssertEqual(Transliterator.ruleBased("sita"), "सित")
    }

    func testRomanFromDevanagari() {
        XCTAssertEqual(engine.transliterator.toRoman(word: "क्या"), "kya")
    }

    func testHinglishUtilities() {
        XCTAssertEqual(engine.hinglish.collapseElongation("bhaaaai"), "bhai")
        XCTAssertEqual(engine.hinglish.conventionalSpelling(of: "thik"), "theek")
        XCTAssertEqual(engine.hinglish.conventionalSpelling(of: "mai"), "main")
        XCTAssertNil(engine.hinglish.conventionalSpelling(of: "hu"))
        XCTAssertEqual(HinglishEngine.phoneticKey("nahi"), HinglishEngine.phoneticKey("nhi"))
    }

    func testTokenizerKeepsSymbolicChunks() {
        XCTAssertEqual(Tokenizer.tokenize("see www.x.com @me").map(\.kind), [.word, .symbolic, .symbolic])
        XCTAssertEqual(Tokenizer.trailingWord(in: "kal mil"), "mil")
        XCTAssertEqual(Tokenizer.trailingWord(in: "kal "), "")
        XCTAssertEqual(Tokenizer.currentSentence(in: "Hello there. kal mil"), "kal mil")
        XCTAssertEqual(Tokenizer.trailingWord(in: "क्या"), "क्या")
    }
}

final class PerformanceTests: XCTestCase {
    func testSuggestionLatencyBudget() {
        let engine = makeEngine()
        let contexts = ["bhai kal", "kya kr rha ", "mai thik hu", "I am going to the off", "teh", "क्या कर", "bhai mai kal office nahi aa paunga", "gharwale"]
        var worst = 0.0, total = 0.0
        var runs = 0
        for _ in 0..<25 {
            for c in contexts {
                let start = CFAbsoluteTimeGetCurrent()
                _ = engine.suggestions(before: c)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                worst = max(worst, elapsed)
                total += elapsed
                runs += 1
            }
        }
        let mean = total / Double(runs) * 1000
        print("suggestion latency: mean \(String(format: "%.2f", mean)) ms, worst \(String(format: "%.2f", worst * 1000)) ms over \(runs) runs")
        XCTAssertLessThan(mean, 16, "Mean suggestion latency must stay under one frame")
    }

    func testModelLoadTime() throws {
        let start = CFAbsoluteTimeGetCurrent()
        _ = try Lexicon(bundle: Lexicon.resourceBundle)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        print("model load: \(String(format: "%.0f", elapsed)) ms")
    }
}
