import XCTest
@testable import BoliKeyKit

/// Records cursor moves exactly as a text field would receive them, and never adjusts them.
private final class RecordingProxy: TextProxying {
    var contextBeforeCursor: String?
    var contextAfterCursor: String?
    private(set) var moves: [Int] = []
    init(before: String, after: String) {
        contextBeforeCursor = before
        contextAfterCursor = after
    }
    func insert(_ text: String) {}
    func deleteBackward() {}
    func moveCursor(by offset: Int) { moves.append(offset) }
}

/// Corrects every word, to show where correction is skipped.
private final class AlwaysCorrect: WordBoundaryDelegate {
    func correction(for word: String, context: String) -> String? { "X" }
    func didUndoCorrection(typed: String, corrected: String) {}
}

final class CursorTests: XCTestCase {
    // MARK: Drag session

    func testPlainTextMovesOneUnitPerCharacter() {
        var session = CursorDragSession(before: "kal milte", after: " hai")
        XCTAssertEqual(session.offset(forSteps: -3).offset, -3)
        XCTAssertEqual(session.offset(forSteps: 2).offset, 2)
    }

    func testEmojiIsOneStep() {
        var session = CursorDragSession(before: "ok 😀", after: "")
        let step = session.offset(forSteps: -1)
        XCTAssertEqual(step.offset, -2, "😀 is two UTF-16 units")
        XCTAssertEqual(step.moved, -1)
        XCTAssertEqual(session.offset(forSteps: -1).offset, -1)
    }

    func testJoinedEmojiIsOneStep() {
        let family = "👨‍👩‍👧"
        var session = CursorDragSession(before: "a" + family, after: "b")
        XCTAssertEqual(session.offset(forSteps: -1).offset, -family.utf16.count)
        XCTAssertEqual(session.offset(forSteps: 1).offset, family.utf16.count)
    }

    func testDevanagariMovesByWholeCharacters() {
        // How many characters a conjunct makes depends on the Unicode version, but crossing all of
        // them must cover every code unit, and never stop inside one.
        let word = "क्या"
        var session = CursorDragSession(before: "हाँ " + word, after: "")
        let back = session.offset(forSteps: -word.count)
        XCTAssertEqual(back.offset, -word.utf16.count)
        XCTAssertEqual(back.moved, -word.count)
    }

    func testStopsAtTheEdgesOfTheText() {
        var session = CursorDragSession(before: "ab", after: "c")
        let left = session.offset(forSteps: -5)
        XCTAssertEqual(left.offset, -2)
        XCTAssertEqual(left.moved, -2)
        XCTAssertEqual(session.offset(forSteps: -1).moved, 0)
        let right = session.offset(forSteps: 9)
        XCTAssertEqual(right.offset, 3)
        XCTAssertEqual(right.moved, 3)
    }

    func testStaleContextIsNotMistakenForMoreText() {
        var session = CursorDragSession(before: "abc", after: "")
        _ = session.offset(forSteps: -3)
        // The field has not caught up: the same text, split where the cursor used to be.
        XCTAssertFalse(session.extend(before: "abc", after: ""))
        XCTAssertEqual(session.offset(forSteps: -1).moved, 0)
    }

    func testMoreSharedTextExtendsTheDrag() {
        var session = CursorDragSession(before: "world", after: "")
        _ = session.offset(forSteps: -5)
        XCTAssertTrue(session.extend(before: "hello 😀 ", after: "world"))
        let more = session.offset(forSteps: -2)
        XCTAssertEqual(more.offset, -3, "a space, then a two-unit emoji")
    }

    // MARK: Input controller

    func testDragSendsGraphemeOffsetsToTheField() {
        let proxy = RecordingProxy(before: "hi 👋🏽", after: " there")
        let input = InputController(proxy: proxy)
        input.beginCursorDrag()
        XCTAssertEqual(input.moveCursor(byCharacters: -1), -1)
        XCTAssertEqual(input.moveCursor(byCharacters: 2), 2)
        input.endCursorDrag()
        XCTAssertEqual(proxy.moves, [-"👋🏽".utf16.count, "👋🏽".utf16.count + 1])
    }

    func testDragUsesTheTextCapturedAtTheStart() {
        let proxy = RecordingProxy(before: "😀😀", after: "")
        let input = InputController(proxy: proxy)
        input.beginCursorDrag()
        input.moveCursor(byCharacters: -1)
        // A field reports its new context late. The session must not read it after each step.
        input.moveCursor(byCharacters: -1)
        XCTAssertEqual(proxy.moves, [-2, -2])
    }

    func testNoMoveAtTheStartSendsNothing() {
        let proxy = RecordingProxy(before: "", after: "abc")
        let input = InputController(proxy: proxy)
        input.beginCursorDrag()
        XCTAssertEqual(input.moveCursor(byCharacters: -3), 0)
        XCTAssertTrue(proxy.moves.isEmpty)
    }

    func testTypingAfterMovingInsertsAtTheCursor() {
        let proxy = StringTextProxy("ab😀cd")
        let input = InputController(proxy: proxy)
        input.configuration.autoCapitalizeEnabled = false
        input.beginCursorDrag()
        input.moveCursor(byCharacters: -3)
        input.endCursorDrag()
        XCTAssertEqual(proxy.contextBeforeCursor, "ab")
        XCTAssertEqual(proxy.contextAfterCursor, "😀cd")
        input.insertCharacter("X")
        XCTAssertEqual(proxy.text, "abX😀cd")
        input.tapBackspace()
        XCTAssertEqual(proxy.text, "ab😀cd")
    }

    func testCapitalisationFollowsTheCursor() {
        let proxy = StringTextProxy("Hi. there")
        let input = InputController(proxy: proxy)
        input.syncAutoCapitalization()
        XCTAssertEqual(input.shift, .off)
        input.beginCursorDrag()
        input.moveCursor(byCharacters: -5)
        input.endCursorDrag()
        XCTAssertEqual(proxy.contextBeforeCursor, "Hi. ")
        XCTAssertEqual(input.shift, .once, "The cursor now starts a sentence")
    }

    func testNoCorrectionInsideAWord() {
        let proxy = StringTextProxy("helo")
        let input = InputController(proxy: proxy)
        let corrector = AlwaysCorrect()
        input.delegate = corrector
        input.configuration.autoCapitalizeEnabled = false
        input.moveCursor(byCharacters: -2)
        input.tapSpace()
        XCTAssertEqual(proxy.text, "he lo", "Splitting a word keeps both halves as typed")
        input.moveCursor(byCharacters: 2)
        input.tapSpace()
        XCTAssertEqual(proxy.text, "he X ", "At the end of a word, correction still applies")
    }

    func testMovingForgetsTheLastCorrection() {
        let proxy = StringTextProxy()
        let input = InputController(proxy: proxy)
        let corrector = AlwaysCorrect()
        input.delegate = corrector
        input.configuration.autoCapitalizeEnabled = false
        for ch in "teh" { input.insertCharacter(String(ch)) }
        input.tapSpace()
        XCTAssertEqual(proxy.text, "X ")
        input.moveCursor(byCharacters: -1)
        input.moveCursor(byCharacters: 1)
        input.tapBackspace()
        XCTAssertEqual(proxy.text, "X", "Backspace after moving deletes, it does not restore the typed word")
    }

    // MARK: String proxy

    func testStringProxyTracksACursor() {
        let proxy = StringTextProxy("kal hai")
        proxy.moveCursor(by: -3)
        XCTAssertEqual(proxy.contextBeforeCursor, "kal ")
        XCTAssertEqual(proxy.contextAfterCursor, "hai")
        proxy.insert("milte ")
        XCTAssertEqual(proxy.text, "kal milte hai")
        proxy.deleteBackward()
        XCTAssertEqual(proxy.text, "kal miltehai")
        proxy.text = "new"
        XCTAssertEqual(proxy.contextBeforeCursor, "new", "Setting the text puts the cursor at its end")
        XCTAssertEqual(proxy.contextAfterCursor, "")
    }

    func testStringProxyNeverStopsInsideACharacter() {
        let proxy = StringTextProxy("a😀")
        proxy.moveCursor(by: -1)
        XCTAssertEqual(proxy.contextBeforeCursor, "a", "Half an emoji snaps to its start")
        proxy.moveCursor(by: 1)
        XCTAssertEqual(proxy.contextBeforeCursor, "a😀")
        proxy.moveCursor(by: -10)
        XCTAssertEqual(proxy.cursor, 0)
        proxy.moveCursor(by: 10)
        XCTAssertEqual(proxy.contextAfterCursor, "")
    }
}
