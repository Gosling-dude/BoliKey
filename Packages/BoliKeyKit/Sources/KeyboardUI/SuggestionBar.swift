#if canImport(UIKit)
import UIKit
import BoliKeyKit

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion)
    func suggestionBarDidTapLanguage(_ bar: SuggestionBar)
    func suggestionBarDidTapStyle(_ bar: SuggestionBar)
}

/// The top strip: language indicator, three suggestions, and the optional style control.
final class SuggestionBar: UIView {
    weak var delegate: SuggestionBarDelegate?
    private let languageButton = UIButton(type: .custom)
    private let styleButton = UIButton(type: .custom)
    private var slots: [UIButton] = []
    private var separators: [UIView] = []
    private var suggestions: [Suggestion] = []
    private var theme: KeyboardTheme
    var showsStyleButton = true { didSet { styleButton.isHidden = !showsStyleButton; setNeedsLayout() } }

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        languageButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        languageButton.titleLabel?.adjustsFontSizeToFitWidth = true
        languageButton.layer.cornerRadius = 12
        languageButton.layer.cornerCurve = .continuous
        languageButton.accessibilityIdentifier = "language-indicator"
        languageButton.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        addSubview(languageButton)

        styleButton.setImage(UIImage(systemName: "wand.and.stars", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        styleButton.accessibilityLabel = "Writing styles"
        styleButton.accessibilityIdentifier = "style-control"
        styleButton.addTarget(self, action: #selector(styleTapped), for: .touchUpInside)
        addSubview(styleButton)

        for index in 0..<3 {
            let button = UIButton(type: .custom)
            button.tag = index
            button.titleLabel?.lineBreakMode = .byTruncatingHead
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.62
            button.titleLabel?.textAlignment = .center
            button.layer.cornerRadius = 8
            button.layer.cornerCurve = .continuous
            button.accessibilityIdentifier = "suggestion-\(index)"
            button.addTarget(self, action: #selector(slotTapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(slotDown(_:)), for: [.touchDown, .touchDragEnter])
            button.addTarget(self, action: #selector(slotUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            addSubview(button)
            slots.append(button)
            if index < 2 {
                let separator = UIView()
                addSubview(separator)
                separators.append(separator)
            }
        }
        apply(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        languageButton.setTitleColor(theme.accent, for: .normal)
        languageButton.backgroundColor = theme.accent.withAlphaComponent(0.13)
        styleButton.tintColor = theme.accent
        separators.forEach { $0.backgroundColor = theme.separator }
        render()
    }

    func setLanguage(_ mode: LanguageMode) {
        languageButton.setTitle(mode.indicator, for: .normal)
        languageButton.accessibilityLabel = "Language: \(mode.displayName). Tap to change."
    }

    func setSuggestions(_ new: [Suggestion]) {
        guard new != suggestions else { return }
        suggestions = new
        render()
    }

    private func render() {
        for (index, button) in slots.enumerated() {
            if index < suggestions.count {
                let s = suggestions[index]
                button.isHidden = false
                button.setTitle(s.display, for: .normal)
                button.setTitleColor(theme.suggestionText, for: .normal)
                button.titleLabel?.font = s.kind == .emoji ? .systemFont(ofSize: 24) : .systemFont(ofSize: 15, weight: s.willAutoApply ? .semibold : .regular)
                button.backgroundColor = s.willAutoApply ? theme.highlightBackground : .clear
                button.accessibilityLabel = accessibilityText(for: s)
            } else {
                button.isHidden = true
                button.setTitle(nil, for: .normal)
            }
        }
        for (index, separator) in separators.enumerated() {
            separator.isHidden = index + 1 >= suggestions.count
        }
    }

    private func accessibilityText(for s: Suggestion) -> String {
        switch s.kind {
        case .preserve: return "Keep as typed: \(s.insertion)"
        case .correction: return "Correct to \(s.insertion)"
        case .improvement: return "Change to \(s.insertion)"
        case .emoji: return "Add \(s.display)"
        default: return s.display
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        languageButton.frame = CGRect(x: 6, y: (h - 26) / 2, width: 46, height: 26)
        let rightWidth: CGFloat = showsStyleButton ? 38 : 4
        if showsStyleButton { styleButton.frame = CGRect(x: bounds.width - rightWidth, y: 0, width: rightWidth, height: h) }
        let left = languageButton.frame.maxX + 4
        let slotWidth = (bounds.width - rightWidth - left) / 3
        for (index, button) in slots.enumerated() {
            button.frame = CGRect(x: left + CGFloat(index) * slotWidth, y: 4, width: slotWidth, height: h - 8).insetBy(dx: 2, dy: 0)
        }
        for (index, separator) in separators.enumerated() {
            separator.frame = CGRect(x: left + CGFloat(index + 1) * slotWidth - 0.5, y: 11, width: 1, height: h - 22)
        }
    }

    @objc private func languageTapped() { delegate?.suggestionBarDidTapLanguage(self) }
    @objc private func styleTapped() { delegate?.suggestionBarDidTapStyle(self) }
    @objc private func slotDown(_ sender: UIButton) { sender.alpha = 0.5 }
    @objc private func slotUp(_ sender: UIButton) { sender.alpha = 1 }

    @objc private func slotTapped(_ sender: UIButton) {
        guard suggestions.indices.contains(sender.tag) else { return }
        delegate?.suggestionBar(self, didSelect: suggestions[sender.tag])
    }
}
#endif
