import XCTest
@testable import BoliKeyKit

final class KeyboardInputTests: XCTestCase {
    private var proxy = StringTextProxy()
    private var input: InputController!
    private var clock: TimeInterval = 1000

    override func setUp() {
        proxy = StringTextProxy()
        input = InputController(proxy: proxy)
        clock = 1000
        input.now = { [unowned self] in clock }
    }

    func testCharactersBackspaceSpaceReturn() {
        input.configuration.autoCapitalizeEnabled = false
        for ch in "abc" { input.insertCharacter(String(ch)) }
        input.tapSpace()
        input.insertCharacter("d")
        XCTAssertEqual(proxy.text, "abc d")
        input.tapBackspace()
        input.tapBackspace()
        XCTAssertEqual(proxy.text, "abc")
        input.tapReturn()
        XCTAssertEqual(proxy.text, "abc\n")
    }

    func testShiftOnceThenOff() {
        input.configuration.autoCapitalizeEnabled = false
        input.syncAutoCapitalization()
        input.tapShift()
        XCTAssertEqual(input.shift, .once)
        input.insertCharacter("a")
        input.insertCharacter("b")
        XCTAssertEqual(proxy.text, "Ab")
        XCTAssertEqual(input.shift, .off)
    }

    func testDoubleTapShiftLocks() {
        input.configuration.autoCapitalizeEnabled = false
        input.tapShift()
        clock += 0.1
        input.tapShift()
        XCTAssertEqual(input.shift, .locked)
        input.insertCharacter("a")
        input.insertCharacter("b")
        XCTAssertEqual(proxy.text, "AB")
        input.tapShift()
        XCTAssertEqual(input.shift, .off)
    }

    func testSlowShiftTapsToggle() {
        input.configuration.autoCapitalizeEnabled = false
        input.tapShift()
        clock += 2
        input.tapShift()
        XCTAssertEqual(input.shift, .off)
    }

    func testAutoCapitalisationAfterSentence() {
        input.syncAutoCapitalization()
        XCTAssertEqual(input.shift, .once)
        input.insertCharacter("h")
        input.insertCharacter("i")
        XCTAssertEqual(input.shift, .off)
        input.insertCharacter(".", respectingShift: false)
        clock += 5
        input.tapSpace()
        XCTAssertEqual(input.shift, .once)
        input.insertCharacter("o")
        XCTAssertEqual(proxy.text, "Hi. O")
    }

    func testAutoCapitalisationAfterDandaAndNewline() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(before: "ठीक है। ", mode: .sentences))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(before: "abc\n", mode: .sentences))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(before: "abc ", mode: .sentences))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(before: "abc", mode: .none))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(before: "abc ", mode: .words))
    }

    func testDoubleSpaceMakesPeriod() {
        input.configuration.autoCapitalizeEnabled = false
        input.insertCharacter("a")
        input.tapSpace()
        clock += 0.2
        input.tapSpace()
        XCTAssertEqual(proxy.text, "a. ")
    }

    func testDoubleSpaceCanBeDisabled() {
        input.configuration.autoCapitalizeEnabled = false
        input.configuration.doubleSpacePeriodEnabled = false
        input.insertCharacter("a")
        input.tapSpace()
        clock += 0.2
        input.tapSpace()
        XCTAssertEqual(proxy.text, "a  ")
    }

    func testPunctuationAfterAcceptedSuggestionReplacesSpace() {
        input.configuration.autoCapitalizeEnabled = false
        input.accept(replacing: "", with: "hello", addSpace: true)
        XCTAssertEqual(proxy.text, "hello ")
        input.insertCharacter(",", respectingShift: false)
        XCTAssertEqual(proxy.text, "hello,")
    }

    func testAcceptReplacesTheTypedWord() {
        input.configuration.autoCapitalizeEnabled = false
        for ch in "tom" { input.insertCharacter(String(ch)) }
        input.accept(replacing: "tom", with: "tomorrow", addSpace: true)
        XCTAssertEqual(proxy.text, "tomorrow ")
    }

    func testAcceptReplacesDevanagariCleanly() {
        input.configuration.autoCapitalizeEnabled = false
        proxy.text = "क्या कर"
        input.accept(replacing: "कर", with: "करना", addSpace: true)
        XCTAssertEqual(proxy.text, "क्या करना ")
    }

    func testDeleteWordBackward() {
        proxy.text = "hello there friend"
        input.deleteWordBackward()
        XCTAssertEqual(proxy.text, "hello there ")
        input.deleteWordBackward()
        XCTAssertEqual(proxy.text, "hello ")
    }

    func testLayoutHasFullQwertyAndRequiredKeys() {
        let rows = KeyboardLayouts.rows(for: .letters, uppercase: false)
        let letters = rows.flatMap { $0 }.filter(\.isCharacter).map(\.label).joined()
        XCTAssertEqual(letters, "qwertyuiopasdfghjklzxcvbnm")
        XCTAssertTrue(rows.flatMap { $0 }.contains { $0.action == .shift })
        XCTAssertTrue(rows.flatMap { $0 }.contains { $0.action == .backspace })
        XCTAssertEqual(KeyboardLayouts.rows(for: .letters, uppercase: true)[0][0].label, "Q")
    }

    func testBottomRowOnlyHasGlobeWhenRequired() {
        let with = KeyboardLayouts.bottomRow(page: .letters, needsGlobe: true, returnLabel: "return", spaceLabel: "space", base: .letters)
        let without = KeyboardLayouts.bottomRow(page: .letters, needsGlobe: false, returnLabel: "return", spaceLabel: "space", base: .letters)
        XCTAssertTrue(with.contains { $0.action == .nextKeyboard })
        XCTAssertFalse(without.contains { $0.action == .nextKeyboard })
        XCTAssertTrue(with.contains { $0.action == .page(.emoji) })
    }

    func testLongPressAlternatesExist() {
        let a = KeyboardLayouts.rows(for: .letters, uppercase: false)[1][0]
        XCTAssertEqual(a.label, "a")
        XCTAssertTrue(a.alternates.contains("ā"))
    }

    func testDevanagariLayoutIsPopulated() {
        XCTAssertGreaterThan(KeyboardLayouts.rows(for: .devanagari, uppercase: false).flatMap { $0 }.filter(\.isCharacter).count, 25)
        XCTAssertGreaterThan(KeyboardLayouts.rows(for: .devanagariAlt, uppercase: false).flatMap { $0 }.filter(\.isCharacter).count, 25)
    }

    func testEmojiCatalog() {
        XCTAssertEqual(EmojiCatalog.categories.count, 7)
        XCTAssertTrue(EmojiCatalog.categories.allSatisfy { !$0.emoji.isEmpty })
    }
}
