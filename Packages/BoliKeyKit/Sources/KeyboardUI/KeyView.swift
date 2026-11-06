#if canImport(UIKit)
import UIKit
import KeyboardInputEngine

/// One key. It does not handle touches itself: the grid resolves those, so that the gaps between keys
/// never swallow a tap. VoiceOver activates it directly.
final class KeyView: UIView {
    let definition: KeyDefinition
    var onAccessibilityActivate: (() -> Void)?
    private let label = UILabel()
    private let icon = UIImageView()
    private var theme: KeyboardTheme
    var isPressed = false { didSet { if oldValue != isPressed { applyColors() } } }
    var isAccented = false { didSet { applyColors() } }

    init(definition: KeyDefinition, theme: KeyboardTheme) {
        self.definition = definition
        self.theme = theme
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        layer.shadowOpacity = 1
        addSubview(label)
        addSubview(icon)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        icon.contentMode = .scaleAspectFit
        isAccessibilityElement = true
        accessibilityTraits = definition.isCharacter ? [.keyboardKey] : [.keyboardKey, .button]
        accessibilityLabel = definition.accessibilityLabel
        if case .character(let c) = definition.action {
            accessibilityIdentifier = "key.\(c)"
        } else {
            accessibilityIdentifier = "key.\(definition.accessibilityLabel)"
        }
        refreshContent(shift: .off)
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    override func accessibilityActivate() -> Bool {
        onAccessibilityActivate?()
        return true
    }

    var isFunctionKey: Bool {
        switch definition.action {
        case .character, .space: return false
        case .returnKey, .shift, .backspace, .page, .nextKeyboard: return true
        }
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        applyColors()
    }

    private func applyColors() {
        let base = isFunctionKey ? theme.functionKeyBackground : theme.keyBackground
        backgroundColor = isPressed ? theme.keyPressed : (isAccented ? theme.accent : base)
        let text: UIColor = (isAccented && !isPressed) ? theme.accentText : theme.keyText
        label.textColor = text
        icon.tintColor = text
        layer.shadowColor = theme.shadow.cgColor
    }

    func setLabel(_ text: String) {
        label.text = text
    }

    func refreshContent(shift: ShiftState) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        func setIcon(_ name: String) {
            icon.image = UIImage(systemName: name, withConfiguration: symbolConfig)
            label.text = nil
        }
        switch definition.action {
        case .shift:
            switch shift {
            case .off: setIcon("shift")
            case .once: setIcon("shift.fill")
            case .locked: setIcon("capslock.fill")
            }
            accessibilityValue = shift == .off ? "Off" : (shift == .locked ? "Caps lock" : "On")
        case .backspace:
            setIcon("delete.left")
        case .nextKeyboard:
            setIcon("globe")
        case .page(.emoji):
            setIcon("face.smiling")
        default:
            icon.image = nil
            label.text = definition.label
            switch definition.action {
            case .character:
                label.font = .systemFont(ofSize: frame.height > 0 && frame.height < 36 ? 19 : 23, weight: .regular)
            case .space:
                label.font = .systemFont(ofSize: 15, weight: .regular)
            default:
                label.font = .systemFont(ofSize: 15, weight: .regular)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 1, dy: 0)
        icon.frame = bounds.insetBy(dx: 2, dy: 6)
    }
}

/// The bubble above a pressed key, and the long-press alternates.
final class KeyPopupView: UIView {
    private let stack = UIStackView()
    private var labels: [UILabel] = []
    private var theme: KeyboardTheme
    private(set) var selectedIndex = 0
    private(set) var options: [String] = []

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = theme.popupBackground
        layer.cornerRadius = 9
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 1)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        addSubview(stack)
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func configure(options: [String], selected: Int, fontSize: CGFloat) {
        self.options = options
        selectedIndex = selected
        labels.forEach { $0.removeFromSuperview() }
        labels = options.map { text in
            let l = UILabel()
            l.text = text
            l.textAlignment = .center
            l.font = .systemFont(ofSize: fontSize)
            l.layer.cornerRadius = 6
            l.layer.masksToBounds = true
            stack.addArrangedSubview(l)
            return l
        }
        updateSelection()
    }

    func select(x: CGFloat) {
        guard !labels.isEmpty, bounds.width > 0 else { return }
        let index = Int((x / bounds.width) * CGFloat(labels.count))
        let clamped = max(0, min(labels.count - 1, index))
        if clamped != selectedIndex {
            selectedIndex = clamped
            updateSelection()
        }
    }

    private func updateSelection() {
        for (i, l) in labels.enumerated() {
            let isSelected = options.count > 1 && i == selectedIndex
            l.backgroundColor = isSelected ? theme.popupSelection : .clear
            l.textColor = isSelected ? theme.accentText : theme.keyText
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = bounds.insetBy(dx: 3, dy: 3)
    }
}
#endif
