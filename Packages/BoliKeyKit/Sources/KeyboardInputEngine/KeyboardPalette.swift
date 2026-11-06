import Foundation

/// A colour as plain numbers, so palettes can be checked without UIKit.
public struct RGBA: Equatable, Hashable, Sendable {
    public let r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
    public static func white(_ w: Double, _ a: Double = 1) -> RGBA { RGBA(w, w, w, a) }

    /// This colour drawn over an opaque one.
    public func over(_ base: RGBA) -> RGBA {
        RGBA(r * a + base.r * (1 - a), g * a + base.g * (1 - a), b * a + base.b * (1 - a), 1)
    }

    /// WCAG relative luminance, ignoring alpha.
    public var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// WCAG contrast ratio between two opaque colours, from 1 to 21.
    public func contrast(with other: RGBA) -> Double {
        let (l1, l2) = (luminance, other.luminance)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}

/// The colours of one keyboard theme. Every theme colours every part, so nothing is left in
/// a colour that only suits another theme.
public struct KeyboardColors: Equatable, Sendable {
    /// Painted behind the keys. Nil keeps the system's own keyboard background.
    public let background: RGBA?
    /// What the background looks like, for previews in the app and for checking contrast.
    public let previewBackground: RGBA
    public let key: RGBA
    public let keyPressed: RGBA
    public let functionKey: RGBA
    public let keyText: RGBA
    public let shadow: RGBA
    /// The return key when it says "send" or "go", the language button and the wand.
    public let accent: RGBA
    /// Text drawn on the accent.
    public let accentText: RGBA
    public let separator: RGBA
    public let suggestionText: RGBA
    public let secondaryText: RGBA
    public let highlight: RGBA
    public let popup: RGBA
    public let panel: RGBA
    /// The chosen alternate in a long-press popup.
    public let popupSelection: RGBA
}

/// A named set of keyboard colours. Classic follows light and dark mode, as BoliKey always has.
/// The others keep their colours in both.
public struct KeyboardPalette: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let light: KeyboardColors
    public let dark: KeyboardColors

    public func colors(dark isDark: Bool) -> KeyboardColors { isDark ? dark : light }

    public static let classicID = "classic"

    /// A theme ID this version does not know, perhaps from a newer one, falls back to Classic.
    public static func named(_ id: String) -> KeyboardPalette {
        all.first { $0.id == id } ?? classic
    }

    public static let all: [KeyboardPalette] = [classic, indigo, saffron, midnight, mint, chai]

    // MARK: Themes

    private static let indigoBrand = RGBA(0.20, 0.18, 0.56)
    private static let saffronBrand = RGBA(1.00, 0.55, 0.20)

    /// The original look, colour for colour.
    public static let classic = KeyboardPalette(
        id: classicID, name: "Classic", detail: "Follows light and dark mode",
        light: KeyboardColors(
            background: nil, previewBackground: RGBA(0.82, 0.84, 0.86),
            key: .white(1), keyPressed: .white(0.84), functionKey: RGBA(0.68, 0.70, 0.75), keyText: .white(0),
            shadow: .white(0, 0.32), accent: indigoBrand, accentText: .white(1), separator: .white(0, 0.14),
            suggestionText: .white(0), secondaryText: .white(0, 0.55), highlight: .white(1), popup: .white(1),
            panel: RGBA(0.84, 0.85, 0.87), popupSelection: indigoBrand),
        dark: KeyboardColors(
            background: nil, previewBackground: .white(0.12),
            key: .white(0.42, 0.55), keyPressed: .white(0.62, 0.7), functionKey: .white(0.26, 0.55), keyText: .white(1),
            shadow: .white(0, 0.5), accent: RGBA(1.00, 0.62, 0.30), accentText: .white(1), separator: .white(1, 0.16),
            suggestionText: .white(1), secondaryText: .white(1, 0.6), highlight: .white(1, 0.16), popup: .white(0.36),
            panel: .white(0.12), popupSelection: indigoBrand))

    public static let indigo = fixed(
        id: "indigo", name: "Indigo", detail: "BoliKey's own colours",
        KeyboardColors(
            background: RGBA(0.12, 0.11, 0.29), previewBackground: RGBA(0.12, 0.11, 0.29),
            key: RGBA(0.27, 0.25, 0.55), keyPressed: RGBA(0.38, 0.36, 0.70), functionKey: RGBA(0.19, 0.18, 0.42), keyText: .white(1),
            shadow: .white(0, 0.35), accent: saffronBrand, accentText: RGBA(0.13, 0.07, 0.02), separator: .white(1, 0.16),
            suggestionText: .white(1), secondaryText: .white(1, 0.68), highlight: .white(1, 0.14), popup: RGBA(0.33, 0.31, 0.64),
            panel: RGBA(0.12, 0.11, 0.29), popupSelection: saffronBrand))

    public static let saffron = fixed(
        id: "saffron", name: "Saffron", detail: "Warm and bright",
        KeyboardColors(
            background: RGBA(1.00, 0.86, 0.72), previewBackground: RGBA(1.00, 0.86, 0.72),
            key: RGBA(1.00, 0.98, 0.95), keyPressed: RGBA(1.00, 0.90, 0.80), functionKey: RGBA(0.99, 0.74, 0.53), keyText: RGBA(0.25, 0.12, 0.04),
            shadow: RGBA(0.55, 0.30, 0.10, 0.35), accent: RGBA(0.72, 0.29, 0.02), accentText: .white(1), separator: .white(0, 0.12),
            suggestionText: RGBA(0.25, 0.12, 0.04), secondaryText: RGBA(0.25, 0.12, 0.04, 0.7), highlight: .white(1), popup: .white(1),
            panel: RGBA(1.00, 0.86, 0.72), popupSelection: RGBA(0.72, 0.29, 0.02)))

    public static let midnight = fixed(
        id: "midnight", name: "Midnight", detail: "Pure black, easy on OLED screens",
        KeyboardColors(
            background: .white(0), previewBackground: .white(0),
            key: RGBA(0.17, 0.17, 0.18), keyPressed: RGBA(0.32, 0.32, 0.34), functionKey: RGBA(0.10, 0.10, 0.11), keyText: .white(1),
            shadow: .white(0, 0), accent: RGBA(0.30, 0.82, 0.78), accentText: .white(0), separator: .white(1, 0.14),
            suggestionText: .white(1), secondaryText: .white(1, 0.62), highlight: .white(1, 0.12), popup: RGBA(0.24, 0.24, 0.26),
            panel: .white(0), popupSelection: RGBA(0.30, 0.82, 0.78)))

    public static let mint = fixed(
        id: "mint", name: "Mint", detail: "Fresh and light",
        KeyboardColors(
            background: RGBA(0.80, 0.93, 0.86), previewBackground: RGBA(0.80, 0.93, 0.86),
            key: .white(1), keyPressed: RGBA(0.88, 0.96, 0.91), functionKey: RGBA(0.64, 0.85, 0.74), keyText: RGBA(0.05, 0.25, 0.16),
            shadow: RGBA(0.10, 0.35, 0.22, 0.3), accent: RGBA(0.05, 0.45, 0.29), accentText: .white(1), separator: .white(0, 0.12),
            suggestionText: RGBA(0.05, 0.25, 0.16), secondaryText: RGBA(0.05, 0.25, 0.16, 0.7), highlight: .white(1), popup: .white(1),
            panel: RGBA(0.80, 0.93, 0.86), popupSelection: RGBA(0.05, 0.45, 0.29)))

    public static let chai = fixed(
        id: "chai", name: "Chai", detail: "Warm brown, like your evening cup",
        KeyboardColors(
            background: RGBA(0.33, 0.23, 0.16), previewBackground: RGBA(0.33, 0.23, 0.16),
            key: RGBA(0.52, 0.38, 0.28), keyPressed: RGBA(0.64, 0.50, 0.39), functionKey: RGBA(0.42, 0.30, 0.21), keyText: RGBA(1.00, 0.96, 0.90),
            shadow: .white(0, 0.35), accent: RGBA(0.96, 0.80, 0.55), accentText: RGBA(0.30, 0.18, 0.10), separator: .white(1, 0.16),
            suggestionText: RGBA(1.00, 0.96, 0.90), secondaryText: RGBA(1.00, 0.96, 0.90, 0.68), highlight: .white(1, 0.14), popup: RGBA(0.44, 0.31, 0.22),
            panel: RGBA(0.33, 0.23, 0.16), popupSelection: RGBA(0.96, 0.80, 0.55)))

    private static func fixed(id: String, name: String, detail: String, _ colors: KeyboardColors) -> KeyboardPalette {
        KeyboardPalette(id: id, name: name, detail: detail, light: colors, dark: colors)
    }
}
