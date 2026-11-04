import UIKit
import BoliKeyKit
import KeyboardUI

final class KeyboardViewController: UIInputViewController, KeyboardHosting, TextProxying {
    private var root: KeyboardRootView?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = KeyboardRootView(host: self)
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.root = root
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: KeyboardViewController, _: UITraitCollection) in
            controller.root?.appearanceDidChange()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeight()
        root?.willAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        root?.textDidChange()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateHeight()
    }

    private func updateHeight() {
        let isLandscape = view.bounds.width > 500 && traitCollection.verticalSizeClass == .compact
        let height: CGFloat = (isLandscape ? 170 : 216) + KeyboardRootView.suggestionBarHeight
        if let heightConstraint {
            if heightConstraint.constant != height { heightConstraint.constant = height }
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: height)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        root?.textDidChange()
    }

    // MARK: TextProxying

    var contextBeforeCursor: String? {
        isSecureField ? nil : textDocumentProxy.documentContextBeforeInput
    }
    var contextAfterCursor: String? {
        isSecureField ? nil : textDocumentProxy.documentContextAfterInput
    }
    func insert(_ text: String) { textDocumentProxy.insertText(text) }
    func deleteBackward() { textDocumentProxy.deleteBackward() }
    func moveCursor(by offset: Int) { textDocumentProxy.adjustTextPosition(byCharacterOffset: offset) }

    // MARK: KeyboardHosting

    var textProxy: TextProxying { self }
    var needsGlobeKey: Bool { needsInputModeSwitchKey }
    var hapticsAllowed: Bool { hasFullAccess }
    var prefersNumericPage: Bool {
        switch textDocumentProxy.keyboardType ?? .default {
        case .numberPad, .decimalPad, .phonePad, .numbersAndPunctuation, .asciiCapableNumberPad: return true
        default: return false
        }
    }
    var usesDarkAppearance: Bool {
        textDocumentProxy.keyboardAppearance == .dark || traitCollection.userInterfaceStyle == .dark
    }

    private var isSecureField: Bool { textDocumentProxy.isSecureTextEntry == true }

    var fieldContext: FieldContext {
        var sensitive = textDocumentProxy.autocorrectionType == .no
        switch textDocumentProxy.keyboardType ?? .default {
        case .URL, .emailAddress, .webSearch, .numberPad, .phonePad, .decimalPad, .asciiCapableNumberPad, .namePhonePad, .twitter:
            sensitive = sensitive || textDocumentProxy.keyboardType != .twitter && textDocumentProxy.keyboardType != .webSearch
        default:
            break
        }
        switch textDocumentProxy.textContentType {
        case .some(.oneTimeCode), .some(.password), .some(.newPassword), .some(.creditCardNumber):
            return FieldContext(isSecure: true)
        default:
            break
        }
        return FieldContext(isSecure: isSecureField, isSensitiveKind: sensitive)
    }

    var autoCapitalizationMode: AutoCapitalizationMode {
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: return .none
        case .words: return .words
        case .allCharacters: return .allCharacters
        default: return .sentences
        }
    }

    var returnKeyLabel: String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: return "go"
        case .google, .yahoo, .search: return "search"
        case .join: return "join"
        case .next: return "next"
        case .route: return "route"
        case .send: return "send"
        case .done: return "done"
        case .continue: return "continue"
        case .emergencyCall: return "call"
        default: return "return"
        }
    }

    func advanceToNextKeyboard() { advanceToNextInputMode() }

    func playKeyClick() {
        guard hasFullAccess else { return }
        UIDevice.current.playInputClick()
    }

    func makeGlobeControl() -> UIControl? {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        return button
    }
}
