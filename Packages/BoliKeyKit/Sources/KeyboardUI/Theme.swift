#if canImport(UIKit)
import UIKit

/// BoliKey's visual identity, shared by the keyboard and the app.
public enum BoliBrand {
    public static let indigo = UIColor(red: 0.20, green: 0.18, blue: 0.56, alpha: 1)
    public static let saffron = UIColor(red: 1.00, green: 0.55, blue: 0.20, alpha: 1)
    public static let tagline = "Type the way you talk."
}

struct KeyboardTheme {
    let keyBackground: UIColor
    let keyPressed: UIColor
    let functionKeyBackground: UIColor
    let keyText: UIColor
    let shadow: UIColor
    let accent: UIColor
    let separator: UIColor
    let suggestionText: UIColor
    let secondaryText: UIColor
    let highlightBackground: UIColor
    let popupBackground: UIColor
    let panelBackground: UIColor

    static func resolve(dark: Bool) -> KeyboardTheme {
        if dark {
            return KeyboardTheme(
                keyBackground: UIColor(white: 0.42, alpha: 0.55),
                keyPressed: UIColor(white: 0.62, alpha: 0.7),
                functionKeyBackground: UIColor(white: 0.26, alpha: 0.55),
                keyText: .white,
                shadow: UIColor(white: 0, alpha: 0.5),
                accent: UIColor(red: 1.00, green: 0.62, blue: 0.30, alpha: 1),
                separator: UIColor(white: 1, alpha: 0.16),
                suggestionText: .white,
                secondaryText: UIColor(white: 1, alpha: 0.6),
                highlightBackground: UIColor(white: 1, alpha: 0.16),
                popupBackground: UIColor(white: 0.36, alpha: 1),
                panelBackground: UIColor(white: 0.12, alpha: 1))
        }
        return KeyboardTheme(
            keyBackground: .white,
            keyPressed: UIColor(white: 0.84, alpha: 1),
            functionKeyBackground: UIColor(red: 0.68, green: 0.70, blue: 0.75, alpha: 1),
            keyText: .black,
            shadow: UIColor(white: 0, alpha: 0.32),
            accent: BoliBrand.indigo,
            separator: UIColor(white: 0, alpha: 0.14),
            suggestionText: .black,
            secondaryText: UIColor(white: 0, alpha: 0.55),
            highlightBackground: .white,
            popupBackground: .white,
            panelBackground: UIColor(red: 0.84, green: 0.85, blue: 0.87, alpha: 1))
    }
}
#endif
