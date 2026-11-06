import XCTest
@testable import BoliKeyKit

final class RupeeAmountTests: XCTestCase {
    private func formatted(_ text: String) -> String? { RupeeAmount.match(endingAt: text)?.formatted }

    func testCurrencyWordsAfterTheNumber() {
        XCTAssertEqual(formatted("500 rs"), "₹500")
        XCTAssertEqual(formatted("500rs"), "₹500")
        XCTAssertEqual(formatted("500/-"), "₹500")
        XCTAssertEqual(formatted("15000 rupaye"), "₹15,000")
        XCTAssertEqual(formatted("2 lakh rupees"), "₹2,00,000")
        XCTAssertEqual(formatted("5k rs"), "₹5,000")
        XCTAssertEqual(formatted("5K RS"), "₹5,000")
        XCTAssertEqual(formatted("5 hazaar rupaye"), "₹5,000")
        XCTAssertEqual(formatted("700 INR"), "₹700")
    }

    func testCurrencyBeforeTheNumber() {
        XCTAssertEqual(formatted("rs 500"), "₹500")
        XCTAssertEqual(formatted("Rs. 1500"), "₹1,500")
        XCTAssertEqual(formatted("Rs.1500"), "₹1,500")
        XCTAssertEqual(formatted("INR 2 lakh"), "₹2,00,000")
        XCTAssertEqual(formatted("₹150000"), "₹1,50,000")
        XCTAssertEqual(formatted("₹ 500"), "₹500")
        XCTAssertEqual(RupeeAmount.match(endingAt: "Rs 500/-")?.replacing, "Rs 500/-", "Both markers go")
    }

    func testLakhAndCroreNeedNoCurrencyWord() {
        XCTAssertEqual(formatted("1.5 lakh"), "₹1,50,000")
        XCTAssertEqual(formatted("1.5lakh"), "₹1,50,000")
        XCTAssertEqual(formatted("10 lac"), "₹10,00,000")
        XCTAssertEqual(formatted("2 cr"), "₹2,00,00,000")
        XCTAssertEqual(formatted("2.75 crore"), "₹2,75,00,000")
    }

    func testGroupingAndPaise() {
        XCTAssertEqual(formatted("1,50,000 rs"), "₹1,50,000")
        XCTAssertEqual(formatted("150,000 rs"), "₹1,50,000", "Western grouping is regrouped")
        XCTAssertEqual(formatted("1500.5 rs"), "₹1,500.50")
        XCTAssertEqual(formatted("99.99 rs"), "₹99.99")
        XCTAssertEqual(formatted("1500.00 rs"), "₹1,500")
        XCTAssertEqual(RupeeAmount.indianGrouping("1"), "1")
        XCTAssertEqual(RupeeAmount.indianGrouping("999"), "999")
        XCTAssertEqual(RupeeAmount.indianGrouping("1000"), "1,000")
        XCTAssertEqual(RupeeAmount.indianGrouping("100000"), "1,00,000")
        XCTAssertEqual(RupeeAmount.indianGrouping("123456789"), "12,34,56,789")
    }

    func testOnlyTheAmountAtTheEndIsReplaced() {
        let m = RupeeAmount.match(endingAt: "phone ka price 15000 rs")
        XCTAssertEqual(m?.replacing, "15000 rs")
        XCTAssertEqual(RupeeAmount.match(endingAt: "phone 15000 rs ")?.replacing, "15000 rs ", "Right after the amount too")
        XCTAssertEqual(formatted("rs 100 aur rs 600"), "₹600")
    }

    func testThingsThatAreNotAmounts() {
        // A bare number may be a phone number, a year or a code, and stays as it is.
        for text in ["500", "500 ", "5k", "5 hazaar", "9876543210", "2026", "kal 2 lakh log aaye", "500 hrs", "500 rsvp",
                     "hrs 500", "rs", "₹500", "₹1,50,000", "500 rs  ", "abc500 rs", "0 rs", "500 rs.", "५०० rs", "Mrs 500"] {
            XCTAssertNil(RupeeAmount.match(endingAt: text), text)
        }
    }

    // MARK: In the keyboard

    func testAmountIsOfferedFirstAndOnlyOffered() throws {
        let engine = makeEngine()
        let first = try XCTUnwrap(engine.suggestions(before: "phone 15000 rs").first)
        XCTAssertEqual(first.kind, .amount)
        XCTAssertEqual(first.display, "₹15,000")
        XCTAssertFalse(first.willAutoApply)
        let harness = TypingHarness(engine: engine)
        harness.type("phone 15000 rs ")
        XCTAssertEqual(harness.proxy.text, "phone 15000 rs ", "Typing on never changes it")
    }

    func testAcceptingAnAmount() throws {
        let engine = makeEngine()
        let harness = TypingHarness(engine: engine)
        harness.type("budget 1.5 lakh")
        let amount = try XCTUnwrap(engine.suggestions(before: harness.proxy.text).first { $0.kind == .amount })
        harness.input.accept(replacing: amount.replacing, with: amount.insertion, addSpace: amount.addsSpace)
        XCTAssertEqual(harness.proxy.text, "budget ₹1,50,000 ")
        engine.didAccept(amount, context: "budget 1.5 lakh")
        XCTAssertTrue(engine.personalization.learned.isEmpty, "An amount is not a word to learn")
    }

    func testNoAmountsInFieldsWithoutLanguage() {
        let engine = makeEngine()
        engine.fieldPolicy = PrivacyManager.policy(for: FieldContext(isSensitiveKind: true))
        XCTAssertTrue(engine.suggestions(before: "500 rs").isEmpty)
    }
}
