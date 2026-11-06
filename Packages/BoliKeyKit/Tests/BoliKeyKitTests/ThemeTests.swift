import XCTest
@testable import BoliKeyKit

final class ThemeTests: XCTestCase {
    private func each(_ body: (KeyboardPalette, Bool, KeyboardColors) -> Void) {
        for palette in KeyboardPalette.all {
            for dark in [false, true] { body(palette, dark, palette.colors(dark: dark)) }
        }
    }

    func testThemesAreDistinctAndClassicIsTheDefault() {
        XCTAssertEqual(Set(KeyboardPalette.all.map(\.id)).count, KeyboardPalette.all.count)
        XCTAssertEqual(KeyboardPalette.all.first?.id, KeyboardPalette.classicID)
        XCTAssertEqual(KeyboardSettings().keyboardTheme, KeyboardPalette.classicID)
        XCTAssertEqual(KeyboardPalette.named("indigo").id, "indigo")
        XCTAssertEqual(KeyboardPalette.named("from-a-newer-version").id, KeyboardPalette.classicID, "Unknown themes fall back")
    }

    func testClassicKeepsTheOriginalColours() {
        let light = KeyboardPalette.classic.light
        XCTAssertNil(light.background, "The system's keyboard background shows through")
        XCTAssertEqual(light.key, .white(1))
        XCTAssertEqual(light.functionKey, RGBA(0.68, 0.70, 0.75))
        XCTAssertEqual(light.accent, RGBA(0.20, 0.18, 0.56))
        XCTAssertEqual(light.panel, RGBA(0.84, 0.85, 0.87))
        let dark = KeyboardPalette.classic.dark
        XCTAssertNil(dark.background)
        XCTAssertEqual(dark.key, .white(0.42, 0.55))
        XCTAssertEqual(dark.functionKey, .white(0.26, 0.55))
        XCTAssertEqual(dark.accent, RGBA(1.00, 0.62, 0.30))
        XCTAssertEqual(dark.popup, .white(0.36))
        XCTAssertEqual(dark.popupSelection, RGBA(0.20, 0.18, 0.56))
    }

    func testOnlyClassicFollowsTheAppearance() {
        for palette in KeyboardPalette.all where palette.id != KeyboardPalette.classicID {
            XCTAssertEqual(palette.light, palette.dark, palette.id)
            XCTAssertNotNil(palette.light.background, "\(palette.id) paints its own background")
        }
    }

    /// WCAG AA: 4.5:1 for text, 3:1 for large text and for the accent against the background.
    func testTextIsReadableInEveryTheme() {
        each { palette, dark, c in
            let name = "\(palette.id)\(dark ? " dark" : "")"
            let bg = c.previewBackground
            XCTAssertGreaterThanOrEqual(c.keyText.contrast(with: c.key.over(bg)), 4.5, "\(name): letter keys")
            XCTAssertGreaterThanOrEqual(c.keyText.contrast(with: c.functionKey.over(bg)), 4.5, "\(name): shift, delete, 123")
            XCTAssertGreaterThanOrEqual(c.keyText.contrast(with: c.keyPressed.over(bg)), 3, "\(name): a key held down")
            XCTAssertGreaterThanOrEqual(c.keyText.contrast(with: c.popup.over(bg)), 4.5, "\(name): the key bubble")
            XCTAssertGreaterThanOrEqual(c.suggestionText.contrast(with: bg), 4.5, "\(name): suggestions")
            XCTAssertGreaterThanOrEqual(c.secondaryText.over(bg).contrast(with: bg), 3, "\(name): secondary text")
            XCTAssertGreaterThanOrEqual(c.accent.over(bg).contrast(with: bg), 3, "\(name): the language button")
        }
    }

    func testAccentTextIsReadableInTheNewThemes() {
        // Classic's dark return key keeps its original white on orange.
        for palette in KeyboardPalette.all where palette.id != KeyboardPalette.classicID {
            let c = palette.light
            XCTAssertGreaterThanOrEqual(c.accentText.contrast(with: c.accent.over(c.previewBackground)), 4.5, "\(palette.id): send key")
            XCTAssertGreaterThanOrEqual(c.accentText.contrast(with: c.popupSelection.over(c.popup)), 4.5, "\(palette.id): chosen alternate")
        }
    }

    func testContrastMaths() {
        XCTAssertEqual(RGBA.white(0).contrast(with: .white(1)), 21, accuracy: 0.01)
        XCTAssertEqual(RGBA.white(0.5).contrast(with: .white(0.5)), 1, accuracy: 0.0001)
        XCTAssertEqual(RGBA.white(1, 0.5).over(.white(0)), .white(0.5))
    }

    func testThemeChoiceSurvivesAndOldFilesDecode() throws {
        var settings = KeyboardSettings()
        settings.keyboardTheme = "midnight"
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardSettings.self, from: data).keyboardTheme, "midnight")
        let old = try JSONDecoder().decode(KeyboardSettings.self, from: Data(#"{"autoCorrectEnabled":false}"#.utf8))
        XCTAssertEqual(old.keyboardTheme, KeyboardPalette.classicID)
    }
}
