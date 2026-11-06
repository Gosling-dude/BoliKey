#if canImport(UIKit)
import UIKit
import KeyboardInputEngine

/// BoliKey's visual identity, shared by the keyboard and the app.
public enum BoliBrand {
    public static let indigo = UIColor(red: 0.20, green: 0.18, blue: 0.56, alpha: 1)
    public static let saffron = UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)
    public static let tagline = "Type the way you talk."
}

extension UIColor {
    public convenience init(_ c: RGBA) {
        self.init(red: CGFloat(c.r), green: CGFloat(c.g), blue: CGFloat(c.b), alpha: CGFloat(c.a))
    }
}

struct KeyboardTheme {
    /// Nil leaves the system's keyboard background showing.
    let keyboardBackground: UIColor?
    let keyBackground: UIColor
    let keyPressed: UIColor
    let functionKeyBackground: UIColor
    let keyText: UIColor
    let shadow: UIColor
    let accent: UIColor
    let accentText: UIColor
    let separator: UIColor
    let suggestionText: UIColor
    let secondaryText: UIColor
    let highlightBackground: UIColor
    let popupBackground: UIColor
    let panelBackground: UIColor
    let popupSelection: UIColor

    static func resolve(dark: Bool) -> KeyboardTheme {
        resolve(palette: .classic, dark: dark)
    }

    static func resolve(palette: KeyboardPalette, dark: Bool) -> KeyboardTheme {
        let c = palette.colors(dark: dark)
        return KeyboardTheme(
            keyboardBackground: c.background.map { UIColor($0) },
            keyBackground: UIColor(c.key),
            keyPressed: UIColor(c.keyPressed),
            functionKeyBackground: UIColor(c.functionKey),
            keyText: UIColor(c.keyText),
            shadow: UIColor(c.shadow),
            accent: UIColor(c.accent),
            accentText: UIColor(c.accentText),
            separator: UIColor(c.separator),
            suggestionText: UIColor(c.suggestionText),
            secondaryText: UIColor(c.secondaryText),
            highlightBackground: UIColor(c.highlight),
            popupBackground: UIColor(c.popup),
            panelBackground: UIColor(c.panel),
            popupSelection: UIColor(c.popupSelection))
    }
}
#endif
