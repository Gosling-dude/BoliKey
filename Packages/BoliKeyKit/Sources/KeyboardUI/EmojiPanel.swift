#if canImport(UIKit)
import UIKit
import KeyboardInputEngine

final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onDismiss: (() -> Void)?
    private let collection: UICollectionView
    private let tabs = UIStackView()
    private let categories = EmojiCatalog.categories
    private var theme: KeyboardTheme

    private final class Cell: UICollectionViewCell {
        let label = UILabel()
        override init(frame: CGRect) {
            super.init(frame: frame)
            label.font = .systemFont(ofSize: 29)
            label.textAlignment = .center
            contentView.addSubview(label)
        }
        required init?(coder: NSCoder) { fatalError("Not used") }
        override func layoutSubviews() {
            super.layoutSubviews()
            label.frame = contentView.bounds
        }
    }

    init(theme: KeyboardTheme) {
        self.theme = theme
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(Cell.self, forCellWithReuseIdentifier: "c")
        collection.accessibilityIdentifier = "emoji-grid"
        addSubview(collection)

        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        addSubview(tabs)
        rebuildTabs()
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        rebuildTabs()
    }

    private func rebuildTabs() {
        tabs.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let abc = UIButton(type: .custom)
        abc.setTitle("ABC", for: .normal)
        abc.setTitleColor(theme.keyText, for: .normal)
        abc.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        abc.accessibilityLabel = "Back to letters"
        abc.accessibilityIdentifier = "emoji-back"
        abc.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        tabs.addArrangedSubview(abc)
        for (index, category) in categories.enumerated() {
            let b = UIButton(type: .custom)
            b.setTitle(category.symbol, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 18)
            b.tag = index
            b.accessibilityLabel = category.name
            b.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabs.addArrangedSubview(b)
        }
        let delete = UIButton(type: .custom)
        delete.setImage(UIImage(systemName: "delete.left"), for: .normal)
        delete.tintColor = theme.keyText
        delete.accessibilityLabel = "Delete"
        delete.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        tabs.addArrangedSubview(delete)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let tabHeight: CGFloat = 38
        tabs.frame = CGRect(x: 4, y: bounds.height - tabHeight, width: bounds.width - 8, height: tabHeight)
        collection.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - tabHeight)
        collection.collectionViewLayout.invalidateLayout()
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { categories.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { categories[section].emoji.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath) as! Cell
        let emoji = categories[indexPath.section].emoji[indexPath.item]
        cell.label.text = emoji
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = emoji
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height = max(30, (collectionView.bounds.height - 16) / 4)
        return CGSize(width: height + 2, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onEmoji?(categories[indexPath.section].emoji[indexPath.item])
    }

    @objc private func tabTapped(_ sender: UIButton) {
        collection.scrollToItem(at: IndexPath(item: 0, section: sender.tag), at: .left, animated: false)
    }

    @objc private func dismissTapped() { onDismiss?() }
    @objc private func backspaceTapped() { onBackspace?() }
}
#endif
