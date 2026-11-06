#if canImport(UIKit)
import UIKit

/// Takes the suggestion bar's place while searching for emoji. The letter keys type the query,
/// which never reaches the text field. Tapping a result types that emoji.
final class EmojiSearchBar: UIView {
    var onSelect: ((String) -> Void)?
    var onClose: (() -> Void)?
    private let field = UIView()
    private let glass = UIImageView()
    private let queryLabel = UILabel()
    private let caret = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let emptyLabel = UILabel()
    private let closeButton = UIButton(type: .custom)
    private var theme: KeyboardTheme
    private var query = ""
    private(set) var results: [String] = []

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        field.layer.cornerRadius = 9
        field.layer.cornerCurve = .continuous
        addSubview(field)
        glass.image = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        glass.contentMode = .center
        field.addSubview(glass)
        queryLabel.font = .systemFont(ofSize: 15)
        queryLabel.lineBreakMode = .byTruncatingHead
        queryLabel.accessibilityIdentifier = "emoji-search-query"
        field.addSubview(queryLabel)
        caret.layer.cornerRadius = 1
        field.addSubview(caret)

        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        addSubview(scroll)
        stack.axis = .horizontal
        stack.spacing = 0
        scroll.addSubview(stack)
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.accessibilityIdentifier = "emoji-search-empty"
        addSubview(emptyLabel)

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)), for: .normal)
        closeButton.accessibilityLabel = "Close emoji search"
        closeButton.accessibilityIdentifier = "emoji-search-close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        apply(theme: theme)
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        field.backgroundColor = theme.keyBackground
        glass.tintColor = theme.secondaryText
        caret.backgroundColor = theme.accent
        emptyLabel.textColor = theme.secondaryText
        closeButton.tintColor = theme.secondaryText
        renderQuery()
    }

    func update(query: String, results: [String]) {
        self.query = query
        if results != self.results {
            self.results = results
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, emoji) in results.enumerated() {
                let button = UIButton(type: .custom)
                button.setTitle(emoji, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 26)
                button.tag = index
                button.accessibilityLabel = emoji
                button.accessibilityIdentifier = "emoji-result-\(index)"
                button.addTarget(self, action: #selector(resultTapped(_:)), for: .touchUpInside)
                button.widthAnchor.constraint(equalToConstant: 40).isActive = true
                stack.addArrangedSubview(button)
            }
            scroll.contentOffset = .zero
        }
        renderQuery()
    }

    private func renderQuery() {
        let isEmpty = query.isEmpty
        queryLabel.text = isEmpty ? "Search emoji" : query
        queryLabel.textColor = isEmpty ? theme.secondaryText : theme.keyText
        queryLabel.accessibilityLabel = "Emoji search"
        queryLabel.accessibilityValue = query
        caret.isHidden = isEmpty
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        emptyLabel.text = trimmed.isEmpty ? "Type to search" : "No emoji for “\(trimmed)”"
        emptyLabel.isHidden = !results.isEmpty
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let closeWidth: CGFloat = 38
        closeButton.frame = CGRect(x: bounds.width - closeWidth, y: 0, width: closeWidth, height: h)
        let fieldWidth = min(160, bounds.width * 0.38)
        field.frame = CGRect(x: 6, y: (h - 32) / 2, width: fieldWidth, height: 32)
        glass.frame = CGRect(x: 4, y: 0, width: 22, height: field.bounds.height)
        let textX = glass.frame.maxX + 2
        let maxText = field.bounds.width - textX - 8
        let textWidth = min(maxText, queryLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 32)).width)
        queryLabel.frame = CGRect(x: textX, y: 0, width: textWidth, height: field.bounds.height)
        caret.frame = CGRect(x: queryLabel.frame.maxX + 1, y: 8, width: 2, height: field.bounds.height - 16)
        let resultsFrame = CGRect(x: field.frame.maxX + 4, y: 0, width: closeButton.frame.minX - field.frame.maxX - 4, height: h)
        scroll.frame = resultsFrame
        emptyLabel.frame = resultsFrame.insetBy(dx: 6, dy: 0)
        let width = CGFloat(results.count) * 40
        stack.frame = CGRect(x: 0, y: 0, width: width, height: h)
        scroll.contentSize = CGSize(width: width, height: h)
    }

    @objc private func resultTapped(_ sender: UIButton) {
        guard results.indices.contains(sender.tag) else { return }
        onSelect?(results[sender.tag])
    }

    @objc private func closeTapped() { onClose?() }
}
#endif
