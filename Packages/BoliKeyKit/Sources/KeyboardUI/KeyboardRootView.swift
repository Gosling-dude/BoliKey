#if canImport(UIKit)
import UIKit
import BoliKeyKit

/// What the keyboard needs from its surroundings. The extension and the in-app preview both provide this.
public protocol KeyboardHosting: AnyObject {
    var textProxy: TextProxying { get }
    var needsGlobeKey: Bool { get }
    var returnKeyLabel: String { get }
    var hapticsAllowed: Bool { get }
    var fieldContext: FieldContext { get }
    var autoCapitalizationMode: AutoCapitalizationMode { get }
    var prefersNumericPage: Bool { get }
    var usesDarkAppearance: Bool { get }
    func advanceToNextKeyboard()
    func playKeyClick()
    /// Places the system's input-mode control over the globe key, if the host has one.
    func makeGlobeControl() -> UIControl?
}

/// The whole keyboard. All engine work runs on one background queue, so that a slow prediction can
/// never delay a key, and keys work from the first instant, before the model has loaded.
public final class KeyboardRootView: UIView, KeyGridDelegate, SuggestionBarDelegate, WordBoundaryDelegate {
    private weak var host: KeyboardHosting?
    private let storeFactory: () -> SharedStore
    private let input: InputController
    private var theme: KeyboardTheme
    /// Paints the theme's background behind everything. Classic leaves it clear.
    private let backdrop = UIView()
    private let bar: SuggestionBar
    private let grid: KeyGridView
    private lazy var emojiPanel: EmojiPanel = makeEmojiPanel()
    private lazy var rewritePanel: RewritePanel = makeRewritePanel()
    private lazy var emojiSearchBar: EmojiSearchBar = makeEmojiSearchBar()
    /// The emoji search, or nil when not searching. While searching, keys type into it, never into the field.
    private var emojiSearchQuery: String?
    private var recentEmoji: [String] = []
    private var panelsLoaded: (emoji: Bool, rewrite: Bool, emojiSearch: Bool) = (false, false, false)
    private var page: KeyboardPage = .letters
    private var settings = KeyboardSettings()
    private var globeControl: UIControl?
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    private let cursorHaptics = UISelectionFeedbackGenerator()

    private let engineQueue = DispatchQueue(label: "com.sumitxfermi.bolikey.engine", qos: .userInitiated)
    private var engine: BoliKeyEngine?
    private var suggestionGeneration = 0
    private var engineReady = false
    private let generationLock = NSLock()
    private var publishedGeneration = 0

    public static let suggestionBarHeight: CGFloat = 44

    public init(host: KeyboardHosting, storeFactory: @escaping () -> SharedStore = { .live() }) {
        self.host = host
        self.storeFactory = storeFactory
        theme = .resolve(dark: host.usesDarkAppearance)
        input = InputController(proxy: host.textProxy)
        bar = SuggestionBar(theme: theme)
        grid = KeyGridView(theme: theme)
        super.init(frame: .zero)
        backdrop.isUserInteractionEnabled = false
        addSubview(backdrop)
        addSubview(bar)
        addSubview(grid)
        bar.delegate = self
        grid.delegate = self
        input.delegate = self
        input.onStateChange = { [weak self] in self?.shiftChanged() }
        grid.globeFrameDidChange = { [weak self] frame in self?.placeGlobe(frame) }
        settings = SettingsStore.load(from: storeFactory())
        applyTheme()
        applySettingsToUI()
        rebuildKeys()
        loadEngine()
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    private func loadEngine() {
        let factory = storeFactory
        engineQueue.async { [weak self] in
            let engine = BoliKeyEngine(store: factory())
            _ = engine.hinglish.phoneticMatches("prewarm")
            DispatchQueue.main.async {
                guard let self else { return }
                self.engine = engine
                self.engineReady = true
                self.refreshSuggestions()
            }
        }
    }

    // MARK: Host events

    /// Call whenever the text field or its traits may have changed.
    public func textDidChange() {
        applyFieldTraits()
        input.syncAutoCapitalization()
        refreshSuggestions()
    }

    /// Call when the keyboard is about to appear.
    public func willAppear() {
        // A search does not survive the keyboard being put away.
        if emojiSearchQuery != nil { endEmojiSearch(showingPanel: false) }
        let store = storeFactory()
        settings = SettingsStore.load(from: store)
        applySettingsToUI()
        applyFieldTraits()
        haptics.prepare()
        // A reused keyboard can open in a field with a different appearance, or with a theme
        // chosen in the app since it was last open.
        applyTheme()
        if let host, host.prefersNumericPage, page == .letters {
            page = .numbers
        }
        rebuildKeys()
        input.syncAutoCapitalization()
        if let engine {
            engineQueue.async { [weak self] in
                engine.reloadFromDisk()
                DispatchQueue.main.async { self?.refreshSuggestions() }
            }
        }
    }

    public func appearanceDidChange() {
        applyTheme()
        rebuildKeys()
    }

    /// The chosen theme's colours, in the field's light or dark appearance.
    private func applyTheme() {
        guard let host else { return }
        theme = .resolve(palette: KeyboardPalette.named(settings.keyboardTheme), dark: host.usesDarkAppearance)
        backdrop.backgroundColor = theme.keyboardBackground
        bar.apply(theme: theme)
        grid.apply(theme: theme)
        if panelsLoaded.emoji { emojiPanel.apply(theme: theme) }
        if panelsLoaded.emojiSearch { emojiSearchBar.apply(theme: theme) }
        if panelsLoaded.rewrite {
            rewritePanel.apply(theme: theme)
            rewritePanel.backgroundColor = theme.panelBackground
        }
    }

    public func globeNeedChanged() {
        rebuildKeys()
    }

    private func applyFieldTraits() {
        guard let host else { return }
        let policy = PrivacyManager.policy(for: host.fieldContext)
        input.configuration.autoCorrectAllowed = policy.mayAutoCorrect && wordsChangeAtSpace
        input.configuration.autoCapitalizationMode = host.autoCapitalizationMode
        if let engine {
            engineQueue.async { engine.fieldPolicy = policy }
        }
    }

    /// Typing Hindi in English letters on the usual keys.
    private var typesHindiPhonetically: Bool { settings.languageMode == .hindi && settings.phoneticHindiEnabled }

    /// Whether finishing a word may change it: a typo fix, or Hindi turning into Devanagari.
    private var wordsChangeAtSpace: Bool { settings.autoCorrectEnabled || typesHindiPhonetically }

    private func applySettingsToUI() {
        // Devanagari has no capital letters.
        input.configuration.autoCapitalizeEnabled = settings.autoCapitalizeEnabled && !typesHindiPhonetically
        input.configuration.doubleSpacePeriodEnabled = settings.doubleSpacePeriodEnabled
        input.configuration.autoCorrectAllowed = wordsChangeAtSpace
        input.configuration.dandaAfterDevanagari = settings.languageMode == .hindi
        bar.setLanguage(settings.languageMode)
        bar.showsStyleButton = settings.styleControlEnabled
    }

    // MARK: Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        backdrop.frame = bounds
        bar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: Self.suggestionBarHeight)
        let content = CGRect(x: 0, y: Self.suggestionBarHeight, width: bounds.width, height: bounds.height - Self.suggestionBarHeight)
        grid.frame = content.insetBy(dx: 0, dy: 0)
        if emojiPanel.superview != nil { emojiPanel.frame = content }
        if emojiSearchBar.superview != nil { emojiSearchBar.frame = bar.frame }
        if rewritePanel.superview != nil { rewritePanel.frame = bounds }
    }

    private func basePage() -> KeyboardPage {
        settings.languageMode == .hindi && !settings.phoneticHindiEnabled ? .devanagari : .letters
    }

    private func rebuildKeys() {
        guard let host else { return }
        // A search's space bar types into the search. Moving the cursor in the field would put the
        // emoji somewhere the user did not choose.
        grid.allowsCursorDrag = emojiSearchQuery == nil
        // Emoji keywords are in Roman letters, so a search always gets the English layout.
        if emojiSearchQuery != nil {
            var rows = KeyboardLayouts.rows(for: .letters, uppercase: false)
            rows.append(KeyboardLayouts.emojiSearchBottomRow(needsGlobe: host.needsGlobeKey))
            grid.setKeys(rows, shift: .off)
            return
        }
        if page == .letters || page == .devanagari { page = basePage() }
        let spaceLabel = settings.languageMode == .hindi ? (settings.phoneticHindiEnabled ? "हिन्दी" : "स्पेस") : "BoliKey"
        var rows = KeyboardLayouts.rows(for: page, uppercase: input.shift.isUppercase)
        rows.append(KeyboardLayouts.bottomRow(page: page, needsGlobe: host.needsGlobeKey, returnLabel: host.returnKeyLabel, spaceLabel: spaceLabel, base: basePage()))
        grid.setKeys(rows, shift: page == .letters ? input.shift : .off)
        grid.setAccented(returnIsAccented(host.returnKeyLabel), for: .returnKey)
        grid.setSpaceLabel(spaceLabel)
    }

    private func returnIsAccented(_ label: String) -> Bool {
        label != "return"
    }

    private func placeGlobe(_ frame: CGRect?) {
        globeControl?.removeFromSuperview()
        globeControl = nil
        guard let frame, let control = host?.makeGlobeControl() else { return }
        control.frame = frame
        control.accessibilityLabel = "Next keyboard"
        control.accessibilityIdentifier = "key.Next keyboard"
        grid.addSubview(control)
        globeControl = control
    }

    private func shiftChanged() {
        if page == .letters, emojiSearchQuery == nil { grid.update(shift: input.shift) }
    }

    // MARK: KeyGridDelegate

    private var hapticsAllowed: Bool { settings.hapticsEnabled && host?.hapticsAllowed == true }

    func gridDidTouchDownKey(_ grid: KeyGridView) {
        if hapticsAllowed {
            haptics.impactOccurred()
        }
        if settings.keyClickEnabled { host?.playKeyClick() }
    }

    func grid(_ grid: KeyGridView, didTrigger action: KeyAction) {
        if emojiSearchQuery != nil {
            searchKeyTapped(action)
            return
        }
        switch action {
        case .character(let s):
            input.insertCharacter(s, respectingShift: page == .letters)
        case .shift:
            input.tapShift()
        case .backspace:
            input.tapBackspace()
        case .space:
            input.tapSpace()
            // After punctuation or space on a symbol page, go back to the letters, like the system keyboard.
            if page == .numbers || page == .symbols {
                page = basePage()
                rebuildKeys()
            }
        case .returnKey:
            input.tapReturn()
        case .page(.emoji):
            showEmoji()
            return
        case .page(let new):
            page = new
            rebuildKeys()
            return
        case .nextKeyboard:
            host?.advanceToNextKeyboard()
            return
        }
        refreshSuggestions()
    }

    func grid(_ grid: KeyGridView, didChooseAlternate text: String) {
        if let query = emojiSearchQuery {
            updateEmojiSearch(query + text.lowercased())
            return
        }
        input.insertCharacter(text, respectingShift: false)
        refreshSuggestions()
    }

    func gridDidRepeatBackspace(_ grid: KeyGridView, byWord: Bool) {
        if let query = emojiSearchQuery {
            updateEmojiSearch(byWord ? "" : String(query.dropLast()))
            return
        }
        if byWord {
            input.deleteWordBackward()
        } else {
            input.tapBackspace()
        }
        refreshSuggestions()
    }

    func gridDidBeginCursorDrag(_ grid: KeyGridView) {
        input.beginCursorDrag()
        if hapticsAllowed {
            cursorHaptics.prepare()
            haptics.impactOccurred()
        }
    }

    func grid(_ grid: KeyGridView, moveCursorBy characters: Int) {
        guard input.moveCursor(byCharacters: characters) != 0 else { return }
        if hapticsAllowed { cursorHaptics.selectionChanged() }
    }

    func gridDidEndCursorDrag(_ grid: KeyGridView) {
        input.endCursorDrag()
        refreshSuggestions()
        // The field reports the new cursor position asynchronously. Look again once it has.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.input.syncAutoCapitalization()
            self?.refreshSuggestions()
        }
    }

    // MARK: Suggestions

    private func refreshSuggestions() {
        guard engineReady, let engine, let host else {
            bar.setSuggestions([])
            return
        }
        suggestionGeneration += 1
        let generation = suggestionGeneration
        generationLock.lock()
        publishedGeneration = generation
        generationLock.unlock()
        // Secure fields: the context is never read at all.
        let policy = PrivacyManager.policy(for: host.fieldContext)
        guard policy.mayReadContext, policy.mayPredict else {
            bar.setSuggestions([])
            return
        }
        // Inside a word, a completion would leave the rest of the word stuck to its end.
        if let next = host.textProxy.contextAfterCursor?.first, Tokenizer.isWordCharacter(next) {
            bar.setSuggestions([])
            return
        }
        let context = host.textProxy.contextBeforeCursor ?? ""
        engineQueue.async { [weak self] in
            // A newer keystroke has already superseded this request.
            guard let self, generation == self.latestGeneration() else { return }
            let suggestions = engine.suggestions(before: context)
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.suggestionGeneration else { return }
                self.bar.setSuggestions(suggestions)
            }
        }
    }

    private func latestGeneration() -> Int {
        generationLock.lock()
        defer { generationLock.unlock() }
        return publishedGeneration
    }

    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion) {
        guard let host else { return }
        let context = host.textProxy.contextBeforeCursor ?? ""
        input.accept(replacing: suggestion.replacing, with: suggestion.insertion, addSpace: suggestion.addsSpace)
        if let engine {
            engineQueue.async { engine.didAccept(suggestion, context: context) }
        }
        refreshSuggestions()
    }

    func suggestionBarDidTapLanguage(_ bar: SuggestionBar) {
        settings.languageMode = settings.languageMode.next
        applyLanguageChange()
    }

    private func applyLanguageChange() {
        let store = storeFactory()
        store.writePrivate(KeyboardLocalState(languageMode: settings.languageMode, activeProfileID: settings.activeProfileID, basedOnRevision: settings.revision), file: StoreFile.keyboardState)
        bar.setLanguage(settings.languageMode)
        applySettingsToUI()
        applyFieldTraits()
        page = basePage()
        rebuildKeys()
        input.syncAutoCapitalization()
        let snapshot = settings
        if let engine {
            engineQueue.async { [weak self] in
                engine.settings = snapshot
                DispatchQueue.main.async { self?.refreshSuggestions() }
            }
        }
    }

    func suggestionBarDidTapStyle(_ bar: SuggestionBar) {
        guard let host else { return }
        let context = host.textProxy.contextBeforeCursor ?? ""
        let sentence = PrivacyManager.policy(for: host.fieldContext).mayReadContext ? Tokenizer.currentSentence(in: context) : ""
        let snapshot = settings
        func present(_ rows: [RewritePanel.Row]) {
            rewritePanel.configure(rows: rows, profiles: snapshot.profiles, activeProfileID: snapshot.activeProfileID)
            rewritePanel.frame = bounds
            addSubview(rewritePanel)
            setNeedsLayout()
        }
        guard let engine, !sentence.isEmpty else {
            present([])
            return
        }
        engineQueue.async {
            var rows = engine.rewrites(of: sentence).map { RewritePanel.Row(title: $0.style.displayName, text: $0.text) }
            let deva = engine.transliterator.toDevanagari(sentence: sentence)
            if deva != sentence { rows.append(.init(title: "देवनागरी", text: deva)) }
            DispatchQueue.main.async { present(rows) }
        }
    }

    private func makeRewritePanel() -> RewritePanel {
        panelsLoaded.rewrite = true
        let panel = RewritePanel(theme: theme)
        panel.backgroundColor = theme.panelBackground
        panel.onClose = { [weak self] in self?.rewritePanel.removeFromSuperview() }
        panel.onSelect = { [weak self] text in
            guard let self, let host = self.host else { return }
            let sentence = Tokenizer.currentSentence(in: host.textProxy.contextBeforeCursor ?? "")
            // A trailing space from typing stays outside the sentence, and is replaced too.
            let before = host.textProxy.contextBeforeCursor ?? ""
            let trailing = String(before.reversed().prefix { $0 == " " })
            self.input.accept(replacing: sentence + trailing, with: text, addSpace: true)
            self.rewritePanel.removeFromSuperview()
            self.refreshSuggestions()
        }
        panel.onProfile = { [weak self] profile in
            guard let self else { return }
            self.settings.activeProfileID = profile.id
            self.settings.languageMode = profile.language
            self.applyLanguageChange()
            self.rewritePanel.configure(rows: [], profiles: self.settings.profiles, activeProfileID: profile.id)
            self.rewritePanel.removeFromSuperview()
        }
        return panel
    }

    // MARK: WordBoundaryDelegate

    public func correction(for word: String, context: String) -> String? {
        guard engineReady, let engine else { return nil }
        // Runs on the main thread within a keystroke. The queue is only busy for a few milliseconds.
        return engineQueue.sync { engine.autoCorrection(for: word, context: context) }
    }

    public func didUndoCorrection(typed: String, corrected: String) {
        guard let engine else { return }
        engineQueue.async { engine.didUndoCorrection(typed: typed, corrected: corrected) }
    }

    // MARK: Emoji

    private func makeEmojiPanel() -> EmojiPanel {
        panelsLoaded.emoji = true
        let panel = EmojiPanel(theme: theme)
        panel.onEmoji = { [weak self] emoji in self?.insertEmoji(emoji) }
        panel.onBackspace = { [weak self] in
            self?.input.tapBackspace()
            self?.refreshSuggestions()
        }
        panel.onDismiss = { [weak self] in
            self?.emojiPanel.removeFromSuperview()
            self?.grid.isHidden = false
        }
        panel.onSearch = { [weak self] in self?.beginEmojiSearch() }
        return panel
    }

    /// Types an emoji picked from the panel or a search, and remembers it for the recent row.
    private func insertEmoji(_ emoji: String) {
        input.insertLiteral(emoji)
        if let engine {
            engineQueue.async { engine.didUseEmoji(emoji) }
        }
        refreshSuggestions()
    }

    private func showEmoji() {
        grid.isHidden = true
        addSubview(emojiPanel)
        setNeedsLayout()
        // The recent row only changes when the panel opens, so nothing moves while picking.
        guard let engine else { return }
        engineQueue.async { [weak self] in
            let recents = engine.personalization.recentEmoji
            DispatchQueue.main.async {
                guard let self else { return }
                self.recentEmoji = recents
                self.emojiPanel.setRecents(recents)
                self.emojiPanel.scrollToStart()
            }
        }
    }

    // MARK: Emoji search

    private func makeEmojiSearchBar() -> EmojiSearchBar {
        panelsLoaded.emojiSearch = true
        let bar = EmojiSearchBar(theme: theme)
        bar.onSelect = { [weak self] emoji in self?.insertEmoji(emoji) }
        bar.onClose = { [weak self] in self?.endEmojiSearch(showingPanel: true) }
        return bar
    }

    private func beginEmojiSearch() {
        emojiPanel.removeFromSuperview()
        grid.isHidden = false
        bar.isHidden = true
        addSubview(emojiSearchBar)
        emojiSearchQuery = ""
        updateEmojiSearch("")
        rebuildKeys()
        setNeedsLayout()
    }

    /// Before anything is typed, the search shows the recent emoji.
    private func updateEmojiSearch(_ query: String) {
        emojiSearchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let results = trimmed.isEmpty ? recentEmoji : EmojiLexicon.shared.search(trimmed, among: EmojiCatalog.allEmoji)
        emojiSearchBar.update(query: query, results: results)
    }

    private func endEmojiSearch(showingPanel: Bool) {
        guard emojiSearchQuery != nil else { return }
        emojiSearchQuery = nil
        emojiSearchBar.removeFromSuperview()
        bar.isHidden = false
        page = basePage()
        rebuildKeys()
        input.syncAutoCapitalization()
        if showingPanel { showEmoji() }
        refreshSuggestions()
    }

    private func searchKeyTapped(_ action: KeyAction) {
        guard let query = emojiSearchQuery else { return }
        switch action {
        case .character(let s):
            updateEmojiSearch(query + s.lowercased())
        case .space:
            if !query.isEmpty, !query.hasSuffix(" ") { updateEmojiSearch(query + " ") }
        case .backspace:
            updateEmojiSearch(String(query.dropLast()))
        case .page(.emoji):
            endEmojiSearch(showingPanel: true)
        case .page, .returnKey:
            endEmojiSearch(showingPanel: false)
        case .nextKeyboard:
            host?.advanceToNextKeyboard()
        case .shift:
            break
        }
    }
}

/// Adapts an in-memory string for the in-app keyboard preview.
public final class PreviewKeyboardHost: KeyboardHosting {
    public let textProxy: TextProxying
    public var needsGlobeKey: Bool { false }
    public var returnKeyLabel: String { "return" }
    public var hapticsAllowed: Bool { true }
    public var fieldContext: FieldContext { FieldContext() }
    public var autoCapitalizationMode: AutoCapitalizationMode { .sentences }
    public var prefersNumericPage: Bool { false }
    public var usesDarkAppearance: Bool { UITraitCollection.current.userInterfaceStyle == .dark }
    public init(proxy: TextProxying) { textProxy = proxy }
    public func advanceToNextKeyboard() {}
    public func playKeyClick() {}
    public func makeGlobeControl() -> UIControl? { nil }
}
#endif
