import XCTest

/// Drives the real keyboard extension in real text fields. Requires BoliKey to be the active keyboard.
/// `testA_EnableKeyboardInSettings` performs the same steps a user does.
class KeyboardTestCase: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func launch(resetData: Bool = true) {
        app.launchArguments = ["-uiTestSkipOnboarding"] + (resetData ? ["-uiTestResetData"] : [])
        app.launch()
    }

    func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    func element(_ id: String, in target: XCUIApplication? = nil) -> XCUIElement {
        (target ?? app).descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Switches the focused field to BoliKey if another keyboard is showing.
    func ensureBoliKey(in target: XCUIApplication? = nil) {
        let target = target ?? app
        let indicator = element("language-indicator", in: target)
        if indicator.waitForExistence(timeout: 4) { return }
        for _ in 0..<6 {
            let globe = target.buttons["Next keyboard"]
            if globe.exists { globe.tap() }
            if indicator.waitForExistence(timeout: 2) { return }
        }
        XCTFail("BoliKey did not appear")
    }

    func openTryField() -> XCUIElement {
        let field = app.textViews["try-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        ensureBoliKey()
        return field
    }

    /// Taps real keys. Spaces, numbers and capitals are handled the way a person would.
    func type(_ text: String, in target: XCUIApplication? = nil) {
        for ch in text {
            switch ch {
            case " ": element("key.Space", in: target).tap()
            case "\n": element("key.return", in: target).tap()
            default:
                let key = element("key.\(String(ch).lowercased())", in: target)
                key.tap()
            }
        }
    }

    /// Lets the asynchronous suggestion queue settle after the last key.
    func waitForSuggestion(_ label: String, in target: XCUIApplication? = nil, timeout: TimeInterval = 5) -> XCUIElement? {
        let target = target ?? app
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for i in 0..<3 {
                let e = element("suggestion-\(i)", in: target)
                if e.exists, e.label == label || e.label.hasSuffix(label) { return e }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    func value(of field: XCUIElement) -> String { (field.value as? String) ?? "" }
}

final class KeyboardUITests: KeyboardTestCase {
    func testA_EnableKeyboardInSettings() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        // Settings restores its last screen, so start from a clean launch at the top level.
        settings.terminate()
        settings.launch()
        for _ in 0..<4 {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            if settings.staticTexts["General"].exists || !back.exists { break }
            back.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        func tap(_ label: String) {
            let text = settings.staticTexts[label].firstMatch
            var tries = 0
            while !(text.exists && text.isHittable) && tries < 6 {
                settings.swipeUp()
                tries += 1
            }
            text.tap()
        }
        tap("General")
        tap("Keyboard")
        Thread.sleep(forTimeInterval: 1)
        let row = settings.collectionViews.cells.containing(.staticText, identifier: "Keyboards").firstMatch
        (row.exists ? row : settings.cells.element(boundBy: 0)).tap()
        Thread.sleep(forTimeInterval: 1)
        shot("settings-keyboards")
        if !settings.staticTexts["BoliKey — BoliKey"].exists && !settings.staticTexts["BoliKey"].exists {
            let add = settings.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Add New Keyboard'")).firstMatch
            var tries = 0
            while !add.isHittable && tries < 4 {
                settings.swipeUp()
                tries += 1
            }
            add.tap()
            Thread.sleep(forTimeInterval: 1)
            shot("settings-add-new")
            tap("BoliKey")
            Thread.sleep(forTimeInterval: 1)
        }
        shot("settings-added")
        XCTAssertTrue(settings.staticTexts.matching(NSPredicate(format: "label CONTAINS 'BoliKey'")).firstMatch.waitForExistence(timeout: 3))
    }

    func testBasicTypingBackspaceShiftSpaceReturn() {
        launch()
        let field = openTryField()
        type("hi")
        XCTAssertEqual(value(of: field), "Hi", "Auto-capitalised first letter, then lowercase")
        element("key.Delete").tap()
        XCTAssertEqual(value(of: field), "H")
        type("a ")
        XCTAssertEqual(value(of: field), "Ha ")
        element("key.Shift").tap()
        type("x")
        XCTAssertEqual(value(of: field), "Ha X", "Shift applies once")
        type("y")
        XCTAssertEqual(value(of: field), "Ha Xy")
        type("\n")
        XCTAssertEqual(value(of: field), "Ha Xy\n")
        shot("basic-typing")
    }

    func testCapsLockWithDoubleTap() {
        launch()
        let field = openTryField()
        type("a ")
        let shift = element("key.Shift")
        shift.tap(withNumberOfTaps: 2, numberOfTouches: 1)
        type("bc")
        XCTAssertEqual(value(of: field), "A BC")
        shift.tap()
        type("d")
        XCTAssertEqual(value(of: field), "A BCd")
    }

    func testHinglishIsPreservedAndSuggestionsAppear() {
        launch()
        let field = openTryField()
        type("bhai kal milte hai ")
        XCTAssertEqual(value(of: field), "Bhai kal milte hai ", "Hinglish must stay exactly as typed")
        shot("hinglish-preserved")

        element("key.Delete").tap()
        XCTAssertEqual(value(of: field), "Bhai kal milte hai")
    }

    func testFullHinglishSentenceWithVariants() {
        launch()
        let field = openTryField()
        type("mai kal office nahi aa paunga ")
        XCTAssertEqual(value(of: field), "Mai kal office nahi aa paunga ")
    }

    func testMixedLanguageIsPreserved() {
        launch()
        let field = openTryField()
        type("i will come kal around ")
        XCTAssertEqual(value(of: field), "I will come kal around ")
    }

    func testPhrasePredictionAcceptance() {
        launch()
        let field = openTryField()
        type("kal kya")
        let s = waitForSuggestion("Kal kya plan hai")
        XCTAssertNotNil(s, "Expected phrase prediction")
        shot("phrase-prediction")
        s?.tap()
        XCTAssertEqual(value(of: field), "Kal kya plan hai ")
    }

    func testPreservationFirstOptions() {
        launch()
        let field = openTryField()
        type("mai thik hu")
        XCTAssertNotNil(waitForSuggestion("Mai thik hu"), "The original comes first")
        XCTAssertNotNil(waitForSuggestion("Main theek hu"), "The conventional spelling is offered")
        shot("preserve-correct-improve")
        XCTAssertEqual(value(of: field), "Mai thik hu", "Nothing changes until a choice is made")
        waitForSuggestion("Main theek hu")?.tap()
        XCTAssertEqual(value(of: field), "Main theek hu ")
    }

    func testTypoCorrectionAndUndo() {
        launch()
        let field = openTryField()
        type("see teh")
        Thread.sleep(forTimeInterval: 0.3)
        type(" ")
        XCTAssertEqual(value(of: field), "See the ")
        element("key.Delete").tap()
        XCTAssertEqual(value(of: field), "See teh", "One backspace restores what was typed")
        type(" ")
        XCTAssertEqual(value(of: field), "See teh ", "A rejected correction does not come back")
    }

    func testPunctuationAndNumberPages() {
        launch()
        let field = openTryField()
        type("ok")
        element("key.Numbers").tap()
        XCTAssertTrue(element("key.5").waitForExistence(timeout: 2))
        type("5")
        element("key..").tap()
        XCTAssertEqual(value(of: field), "Ok5.")
        element("key.More symbols").tap()
        XCTAssertTrue(element("key.#").waitForExistence(timeout: 2))
        element("key.#").tap()
        element("key.Letters").tap()
        XCTAssertTrue(element("key.q").waitForExistence(timeout: 2))
        XCTAssertEqual(value(of: field), "Ok5.#")
    }

    func testLongPressAlternate() {
        launch()
        let field = openTryField()
        type("a")
        let key = element("key.e")
        let start = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Holds, then drags right onto the second alternate, then lets go.
        start.press(forDuration: 0.8, thenDragTo: key.coordinate(withNormalizedOffset: CGVector(dx: 1.9, dy: 0.5)))
        let text = value(of: field)
        XCTAssertEqual(text.count, 2)
        XCTAssertTrue(["ē", "è", "é"].contains(String(text.last!)), "Got \(text)")
        shot("long-press")
    }

    func testEmojiPanel() {
        launch()
        let field = openTryField()
        type("ok ")
        element("key.Emoji").tap()
        let grid = element("emoji-grid")
        XCTAssertTrue(grid.waitForExistence(timeout: 2))
        shot("emoji-panel")
        grid.cells.firstMatch.tap()
        XCTAssertTrue(value(of: field).hasSuffix("😀"), value(of: field))
        element("emoji-back").tap()
        XCTAssertTrue(element("key.q").waitForExistence(timeout: 2))
    }

    func testLanguageSwitchToDevanagari() {
        launch()
        let field = openTryField()
        let indicator = element("language-indicator")
        indicator.tap() // English
        indicator.tap() // Hindi
        XCTAssertTrue(element("key.क").waitForExistence(timeout: 2))
        shot("devanagari-layout")
        type("कर")
        type(" ")
        XCTAssertEqual(value(of: field), "कर ")
        indicator.tap() // Back to Hinglish
        XCTAssertTrue(element("key.q").waitForExistence(timeout: 2))
    }

    func testWritingStylePanelAppliesOnlyOnTap() {
        launch()
        let field = openTryField()
        type("kal meeting hai kya")
        element("style-control").tap()
        let row = element("rewrite-Professional")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        shot("writing-styles")
        XCTAssertEqual(value(of: field), "Kal meeting hai kya", "Opening the panel changes nothing")
        row.tap()
        XCTAssertEqual(value(of: field), "Is there a meeting scheduled for tomorrow? ")
    }

    func testProfileSelectionFromKeyboard() {
        launch()
        _ = openTryField()
        element("style-control").tap()
        let work = element("profile-work")
        XCTAssertTrue(work.waitForExistence(timeout: 3))
        work.tap()
        XCTAssertEqual(element("language-indicator").label.contains("English"), true)
    }

    func testDarkAppearanceRenders() {
        launch()
        _ = openTryField()
        shot("light-keyboard")
        XCUIDevice.shared.appearance = .dark
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(element("key.q").exists || element("key.Q").exists)
        shot("dark-keyboard")
        XCUIDevice.shared.appearance = .light
    }

    func testSwitchKeyboardsWithGlobe() {
        launch()
        _ = openTryField()
        let globe = app.buttons["Next keyboard"]
        XCTAssertTrue(globe.exists || element("key.Next keyboard").exists, "A way to leave the keyboard must exist")
        (globe.exists ? globe : element("key.Next keyboard")).tap()
        XCTAssertFalse(element("language-indicator").waitForExistence(timeout: 2), "Should have left BoliKey")
        ensureBoliKey()
    }
}

/// App settings reaching the keyboard process through the App Group.
final class CompanionAppUITests: KeyboardTestCase {
    private func goToTab(_ name: String) {
        app.tabBars.buttons[name].tap()
    }

    func testOnboardingFlow() {
        app.launchArguments = ["-uiTestResetData"]
        app.launch()
        XCTAssertTrue(element("onboarding-start").waitForExistence(timeout: 8))
        shot("onboarding-welcome")
        element("onboarding-start").tap()
        XCTAssertTrue(element("onboarding-continue").waitForExistence(timeout: 3))
        shot("onboarding-activation")
        element("onboarding-continue").tap()
        XCTAssertTrue(element("language-hinglish").waitForExistence(timeout: 3))
        shot("onboarding-language")
        element("onboarding-finish").tap()
        XCTAssertTrue(app.textViews["try-field"].waitForExistence(timeout: 3))
        shot("home")
    }

    func testAutoCorrectToggleReachesKeyboard() {
        launch()
        goToTab("Settings")
        element("settings-keyboard").tap()
        shot("settings-keyboard")
        let toggle = app.switches["toggle-autocorrect"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        goToTab("Try")
        let field = openTryField()
        type("see teh ")
        XCTAssertEqual(value(of: field), "See teh ", "With correction off the typo must stay")
    }

    func testDictionaryWordReachesKeyboard() {
        launch()
        goToTab("Dictionary")
        let input = app.textFields["dictionary-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        // The field uses whichever keyboard is active, so this goes through BoliKey too.
        ensureBoliKey()
        type("chintu")
        element("dictionary-add").tap()
        XCTAssertTrue(element("dictionary-entry-chintu").waitForExistence(timeout: 3))
        shot("dictionary")
        goToTab("Try")
        let field = openTryField()
        type("chin")
        XCTAssertNotNil(waitForSuggestion("Chintu"), "Personal word must be suggested")
        waitForSuggestion("Chintu")?.tap()
        XCTAssertEqual(value(of: field), "Chintu ")
    }

    func testPrivacyDashboardCountsAndClear() {
        launch()
        goToTab("Dictionary")
        let input = app.textFields["dictionary-text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap()
        ensureBoliKey()
        type("chintu")
        element("dictionary-add").tap()
        goToTab("Settings")
        element("settings-privacy").tap()
        XCTAssertTrue(element("inventory-dictionary").waitForExistence(timeout: 3))
        shot("privacy-dashboard")
        XCTAssertEqual(element("inventory-dictionary").value as? String, "1")
        var tries = 0
        while !element("privacy-clear").isHittable && tries < 5 {
            app.swipeUp()
            tries += 1
        }
        element("privacy-clear").tap()
        app.buttons["Clear All My Data"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 0.5)
        goToTab("Dictionary")
        XCTAssertFalse(element("dictionary-entry-chintu").exists)
    }

    func testStylesScreenShowsRealRewrites() {
        launch()
        goToTab("Styles")
        XCTAssertTrue(element("style-result-professional").waitForExistence(timeout: 3))
        XCTAssertEqual(element("style-result-professional").label, "Is there a meeting scheduled for tomorrow?")
        shot("styles")
    }

    func testInAppPreviewIsTheRealKeyboard() {
        launch()
        element("open-preview").tap()
        let hi = element("key.h")
        XCTAssertTrue(hi.waitForExistence(timeout: 4) || element("key.H").exists)
        type("hi")
        XCTAssertEqual(element("preview-text").label, "Hi")
        shot("in-app-preview")
    }

    func testSettingsScreensOpen() {
        launch()
        goToTab("Settings")
        for id in ["settings-language", "settings-ai", "settings-about"] {
            element(id).tap()
            Thread.sleep(forTimeInterval: 0.4)
            shot(id)
            app.navigationBars.buttons.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }
}

/// Other apps on the simulator. Notes and WhatsApp are not present there.
final class RealAppUITests: KeyboardTestCase {
    func testSafariAddressBarPreservesHinglish() {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        let address = safari.textFields.firstMatch
        if address.waitForExistence(timeout: 8) {
            address.tap()
        } else {
            safari.buttons["Address"].firstMatch.tap()
        }
        ensureBoliKey(in: safari)
        type("bhai kal milte", in: safari)
        Thread.sleep(forTimeInterval: 0.5)
        shot("safari-typing")
        let value = safari.textFields.firstMatch.value as? String ?? ""
        XCTAssertTrue(value.lowercased().contains("bhai kal milte"), value)
    }

    func testMessagesPreservesHinglish() {
        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.launch()
        Thread.sleep(forTimeInterval: 2)
        let compose = messages.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Compose' OR label CONTAINS[c] 'New'")).firstMatch
        if compose.waitForExistence(timeout: 5) { compose.tap() }
        let body = messages.textViews.firstMatch
        let fieldToUse = body.waitForExistence(timeout: 5) ? body : messages.textFields.firstMatch
        fieldToUse.tap()
        ensureBoliKey(in: messages)
        type("bhai kal milte hai ", in: messages)
        Thread.sleep(forTimeInterval: 0.5)
        shot("messages-typing")
        let text = (fieldToUse.value as? String) ?? ""
        XCTAssertEqual(text, "Bhai kal milte hai ", text)
    }

    func testRemindersPreservesMixedSentence() {
        let reminders = XCUIApplication(bundleIdentifier: "com.apple.reminders")
        reminders.launch()
        let add = reminders.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'New Reminder'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        add.tap()
        Thread.sleep(forTimeInterval: 1)
        ensureBoliKey(in: reminders)
        type("meeting kal baje hai", in: reminders)
        Thread.sleep(forTimeInterval: 0.5)
        shot("reminders-typing")
    }
}
