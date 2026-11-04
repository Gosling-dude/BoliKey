#if canImport(UIKit)
import UIKit
import BoliKeyKit

/// Optional rewrites of the current sentence, and manual profile selection.
/// Nothing here runs or changes text until the user taps a row.
final class RewritePanel: UIView {
    struct Row {
        let title: String
        let text: String
    }

    var onSelect: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onProfile: ((LanguageProfile) -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let profileScroll = UIScrollView()
    private let profileStack = UIStackView()
    private let closeButton = UIButton(type: .custom)
    private let emptyLabel = UILabel()
    private var theme: KeyboardTheme
    private var profiles: [LanguageProfile] = []

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        accessibilityIdentifier = "rewrite-panel"
        profileScroll.showsHorizontalScrollIndicator = false
        profileStack.axis = .horizontal
        profileStack.spacing = 6
        profileScroll.addSubview(profileStack)
        addSubview(profileScroll)
        stack.axis = .vertical
        stack.spacing = 5
        scroll.addSubview(stack)
        addSubview(scroll)
        closeButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        closeButton.accessibilityLabel = "Back to keyboard"
        closeButton.accessibilityIdentifier = "rewrite-close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(closeButton)
        emptyLabel.text = "Type a sentence, then choose how it should sound."
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.numberOfLines = 0
        emptyLabel.textAlignment = .center
        addSubview(emptyLabel)
        apply(theme: theme)
        // The system's scroll-edge blur would smear content in a panel this small.
        if #available(iOS 26.0, *) {
            for view in [scroll, profileScroll] {
                view.topEdgeEffect.isHidden = true
                view.bottomEdgeEffect.isHidden = true
                view.leftEdgeEffect.isHidden = true
                view.rightEdgeEffect.isHidden = true
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        closeButton.tintColor = theme.keyText
        emptyLabel.textColor = theme.secondaryText
    }

    func configure(rows: [Row], profiles: [LanguageProfile], activeProfileID: String) {
        self.profiles = profiles
        profileStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, profile) in profiles.enumerated() {
            let b = UIButton(type: .custom)
            b.setTitle("  \(profile.name)  ", for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            let isActive = profile.id == activeProfileID
            b.backgroundColor = isActive ? theme.accent : theme.keyBackground
            b.setTitleColor(isActive ? .white : theme.keyText, for: .normal)
            b.layer.cornerRadius = 13
            b.layer.cornerCurve = .continuous
            b.tag = index
            b.accessibilityIdentifier = "profile-\(profile.id)"
            b.accessibilityValue = isActive ? "Selected" : nil
            b.addTarget(self, action: #selector(profileTapped(_:)), for: .touchUpInside)
            profileStack.addArrangedSubview(b)
        }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLabel.isHidden = !rows.isEmpty
        for (index, row) in rows.enumerated() {
            let b = UIButton(type: .custom)
            b.tag = index
            b.backgroundColor = theme.keyBackground
            b.layer.cornerRadius = 9
            b.layer.cornerCurve = .continuous
            b.contentHorizontalAlignment = .leading
            b.titleLabel?.numberOfLines = 2
            b.titleLabel?.lineBreakMode = .byTruncatingTail
            let text = NSMutableAttributedString(string: row.title + "\n", attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: theme.accent,
            ])
            text.append(NSAttributedString(string: row.text, attributes: [.font: UIFont.systemFont(ofSize: 15), .foregroundColor: theme.keyText]))
            b.setAttributedTitle(text, for: .normal)
            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
            config.attributedTitle = AttributedString(text)
            config.titleAlignment = .leading
            b.configuration = config
            b.accessibilityIdentifier = "rewrite-\(row.title)"
            b.accessibilityLabel = "\(row.title): \(row.text)"
            b.addAction(UIAction { [weak self] _ in self?.onSelect?(row.text) }, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        closeButton.frame = CGRect(x: bounds.width - 44, y: 8, width: 40, height: 30)
        profileScroll.frame = CGRect(x: 6, y: 10, width: bounds.width - 54, height: 26)
        let size = profileStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        profileStack.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: 26))
        profileScroll.contentSize = profileStack.frame.size
        scroll.frame = CGRect(x: 6, y: 44, width: bounds.width - 12, height: bounds.height - 46)
        let rowSize = stack.systemLayoutSizeFitting(CGSize(width: scroll.bounds.width, height: UIView.layoutFittingCompressedSize.height),
                                                    withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        stack.frame = CGRect(x: 0, y: 0, width: scroll.bounds.width, height: rowSize.height)
        scroll.contentSize = stack.frame.size
        emptyLabel.frame = scroll.frame.insetBy(dx: 24, dy: 0)
    }

    @objc private func closeTapped() { onClose?() }

    @objc private func profileTapped(_ sender: UIButton) {
        guard profiles.indices.contains(sender.tag) else { return }
        onProfile?(profiles[sender.tag])
    }
}
#endif
