#if canImport(UIKit)
import UIKit
import KeyboardInputEngine

final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onSearch: (() -> Void)?
    private let collection: UICollectionView
    private let tabs = UIStackView()
    /// The recent row, when there is one, then the fixed categories.
    private var sections = EmojiCatalog.categories
    private var theme: KeyboardTheme

    static let recentName = "Recent"

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

    /// Shows the emoji picked most recently first. An empty list hides the row.
    func setRecents(_ recents: [String]) {
        let recentSection = recents.isEmpty ? [] : [EmojiCatalog.Category(name: Self.recentName, symbol: "🕘", emoji: recents)]
        let updated = recentSection + EmojiCatalog.categories
        guard updated.map(\.emoji) != sections.map(\.emoji) else { return }
        sections = updated
        collection.reloadData()
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
        let search = UIButton(type: .custom)
        search.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
        search.tintColor = theme.keyText
        search.accessibilityLabel = "Search emoji"
        search.accessibilityIdentifier = "emoji-search"
        search.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        tabs.addArrangedSubview(search)
        for (index, category) in sections.enumerated() {
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

    /// Opens at the start, so the recent row is the first thing seen.
    func scrollToStart() {
        guard !sections.isEmpty else { return }
        collection.layoutIfNeeded()
        collection.scrollToItem(at: IndexPath(item: 0, section: 0), at: .left, animated: false)
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { sections[section].emoji.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath) as! Cell
        let emoji = sections[indexPath.section].emoji[indexPath.item]
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
        onEmoji?(sections[indexPath.section].emoji[indexPath.item])
    }

    @objc private func tabTapped(_ sender: UIButton) {
        collection.scrollToItem(at: IndexPath(item: 0, section: sender.tag), at: .left, animated: false)
    }

    @objc private func dismissTapped() { onDismiss?() }
    @objc private func backspaceTapped() { onBackspace?() }
    @objc private func searchTapped() { onSearch?() }
}
#endif
