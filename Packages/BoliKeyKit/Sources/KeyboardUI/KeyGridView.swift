#if canImport(UIKit)
import UIKit
import KeyboardInputEngine

protocol KeyGridDelegate: AnyObject {
    func grid(_ grid: KeyGridView, didTrigger action: KeyAction)
    func grid(_ grid: KeyGridView, didChooseAlternate text: String)
    func gridDidRepeatBackspace(_ grid: KeyGridView, byWord: Bool)
    func gridDidBeginCursorDrag(_ grid: KeyGridView)
    /// Whole characters, negative to the left.
    func grid(_ grid: KeyGridView, moveCursorBy characters: Int)
    func gridDidEndCursorDrag(_ grid: KeyGridView)
    func gridDidTouchDownKey(_ grid: KeyGridView)
}

/// Lays out the keys and resolves every touch to the nearest key.
///
/// Characters commit on touch up, or as soon as the next finger lands. That is what makes fast
/// two-thumb typing lose nothing.
final class KeyGridView: UIView {
    weak var delegate: KeyGridDelegate?
    /// Called so that the host can put the system's input-mode button over the globe key.
    var globeFrameDidChange: ((CGRect?) -> Void)?
    private(set) var keyViews: [[KeyView]] = []
    private var theme: KeyboardTheme
    private let horizontalGap: CGFloat = 6
    private let verticalGap: CGFloat = 11
    private let sideInset: CGFloat = 3
    /// Sliding this far along the space bar moves the cursor without waiting for a long press.
    static let cursorSlideThreshold: CGFloat = 14
    /// Finger travel for each character the cursor moves.
    static let cursorStep: CGFloat = 9
    private static let cursorHoldDelay: TimeInterval = 0.4

    private final class ActiveTouch {
        let key: KeyView
        let startX: CGFloat
        var timer: Timer?
        var repeats = 0
        var showingAlternates = false
        var draggingCursor = false
        /// Where the finger was at the last whole cursor step, or its latest position before a drag.
        var lastCursorX: CGFloat
        init(key: KeyView, x: CGFloat) {
            self.key = key
            startX = x
            lastCursorX = x
        }
    }
    private var active: [ObjectIdentifier: ActiveTouch] = [:]
    private var pendingOrder: [ObjectIdentifier] = []
    private var popup: KeyPopupView?
    /// The touch moving the cursor. While there is one, the keyboard is a trackpad and other keys do nothing.
    private var cursorTouch: ActiveTouch?
    /// Off while the keys type into something other than the field, such as the emoji search.
    /// The space bar then only types a space.
    var allowsCursorDrag = true

    init(theme: KeyboardTheme) {
        self.theme = theme
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("Not used") }

    func setKeys(_ rows: [[KeyDefinition]], shift: ShiftState) {
        cancelAllTouches()
        subviews.forEach { $0.removeFromSuperview() }
        keyViews = rows.map { row in
            row.map { definition in
                let view = KeyView(definition: definition, theme: theme)
                view.onAccessibilityActivate = { [weak self] in
                    guard let self else { return }
                    self.delegate?.grid(self, didTrigger: definition.action)
                }
                addSubview(view)
                return view
            }
        }
        update(shift: shift)
        setNeedsLayout()
    }

    func update(shift: ShiftState) {
        for row in keyViews {
            for key in row {
                if case .character(let s) = key.definition.action {
                    let text = shift.isUppercase ? s.uppercased() : s
                    key.setLabel(text)
                    key.accessibilityLabel = text
                } else {
                    key.refreshContent(shift: shift)
                }
            }
        }
    }

    func apply(theme: KeyboardTheme) {
        self.theme = theme
        keyViews.joined().forEach { $0.apply(theme: theme) }
    }

    func setAccented(_ accented: Bool, for action: KeyAction) {
        keyViews.joined().first { $0.definition.action == action }?.isAccented = accented
    }

    func setSpaceLabel(_ text: String) {
        keyViews.joined().first { $0.definition.action == .space }?.setLabel(text)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !keyViews.isEmpty else { return }
        let rowCount = CGFloat(keyViews.count)
        let usable = bounds.width - sideInset * 2
        let rowHeight = (bounds.height - verticalGap * (rowCount - 1) - 4) / rowCount
        // Letters share the width of the widest character row, so narrower rows centre neatly.
        let letterRows = keyViews.dropLast()
        let unit = letterRows.map { row -> CGFloat in
            let weights = row.reduce(CGFloat(0)) { $0 + $1.definition.width }
            return (usable - horizontalGap * CGFloat(row.count - 1)) / weights
        }.min() ?? 30
        var y: CGFloat = 2
        var globeFrame: CGRect?
        for (index, row) in keyViews.enumerated() {
            let weights = row.reduce(CGFloat(0)) { $0 + $1.definition.width }
            let gaps = horizontalGap * CGFloat(row.count - 1)
            let isLast = index == keyViews.count - 1
            let rowUnit = isLast ? (usable - gaps) / weights : unit
            let rowWidth = rowUnit * weights + gaps
            var x = sideInset + (usable - rowWidth) / 2
            for key in row {
                let width = rowUnit * key.definition.width
                key.frame = CGRect(x: x, y: y, width: width, height: rowHeight).integral
                key.setNeedsLayout()
                if key.definition.action == .nextKeyboard { globeFrame = key.frame }
                x += width + horizontalGap
            }
            y += rowHeight + verticalGap
        }
        globeFrameDidChange?(globeFrame)
    }

    private func key(at point: CGPoint) -> KeyView? {
        var best: KeyView?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for key in keyViews.joined() {
            let frame = key.frame
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            let d = dx * dx + dy * dy
            if d < bestDistance {
                bestDistance = d
                best = key
            }
        }
        return best
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard cursorTouch == nil, let key = key(at: point) else { continue }
            // Rollover: the previous character is committed the moment another finger lands.
            commitPendingCharacters()
            let state = ActiveTouch(key: key, x: point.x)
            let id = ObjectIdentifier(touch)
            active[id] = state
            pendingOrder.append(id)
            key.isPressed = true
            delegate?.gridDidTouchDownKey(self)
            begin(state)
        }
    }

    private func begin(_ state: ActiveTouch) {
        switch state.key.definition.action {
        case .character:
            showPreview(for: state.key)
            if !state.key.definition.alternates.isEmpty {
                state.timer = .scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self, weak state] _ in
                    guard let self, let state else { return }
                    self.showAlternates(state)
                }
            }
        case .backspace:
            delegate?.grid(self, didTrigger: .backspace)
            state.timer = .scheduledTimer(withTimeInterval: 0.42, repeats: false) { [weak self, weak state] _ in
                guard let self, let state else { return }
                self.startRepeatingBackspace(state)
            }
        case .shift:
            delegate?.grid(self, didTrigger: .shift)
        case .space:
            state.timer = .scheduledTimer(withTimeInterval: Self.cursorHoldDelay, repeats: false) { [weak self, weak state] _ in
                guard let self, let state else { return }
                self.beginCursorDrag(state, from: state.lastCursorX)
            }
        default:
            break
        }
    }

    private func startRepeatingBackspace(_ state: ActiveTouch) {
        state.timer = .scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self, weak state] timer in
            guard let self, let state else {
                timer.invalidate()
                return
            }
            state.repeats += 1
            // After about two seconds of holding, delete whole words.
            let byWord = state.repeats > 22
            if byWord, state.repeats % 3 != 0 { return }
            self.delegate?.gridDidRepeatBackspace(self, byWord: byWord)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let state = active[ObjectIdentifier(touch)] else { continue }
            let point = touch.location(in: self)
            if state.showingAlternates, let popup {
                popup.select(x: touch.location(in: popup).x)
            } else if state.key.definition.action == .space {
                if !state.draggingCursor {
                    let slide = point.x - state.startX
                    if abs(slide) >= Self.cursorSlideThreshold {
                        // Counted from where the slide crossed the threshold, so a quick flick moves too.
                        beginCursorDrag(state, from: state.startX + (slide > 0 ? 1 : -1) * Self.cursorSlideThreshold)
                    } else {
                        state.lastCursorX = point.x
                    }
                }
                if state.draggingCursor { advanceCursor(state, to: point.x) }
            }
        }
    }

    // MARK: Cursor

    private func beginCursorDrag(_ state: ActiveTouch, from x: CGFloat) {
        guard allowsCursorDrag, !state.draggingCursor, cursorTouch == nil else { return }
        state.timer?.invalidate()
        state.draggingCursor = true
        state.lastCursorX = x
        cursorTouch = state
        hidePopup()
        keyViews.joined().forEach { $0.setTrackpadAppearance(true) }
        delegate?.gridDidBeginCursorDrag(self)
    }

    private func advanceCursor(_ state: ActiveTouch, to x: CGFloat) {
        // The remainder carries over, so a slow drag and a fast one move the same distance.
        let steps = Int((x - state.lastCursorX) / Self.cursorStep)
        guard steps != 0 else { return }
        state.lastCursorX += CGFloat(steps) * Self.cursorStep
        delegate?.grid(self, moveCursorBy: steps)
    }

    private func endCursorDrag() {
        guard cursorTouch != nil else { return }
        cursorTouch = nil
        keyViews.joined().forEach { $0.setTrackpadAppearance(false) }
        delegate?.gridDidEndCursorDrag(self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let state = active.removeValue(forKey: id) else { continue }
            pendingOrder.removeAll { $0 == id }
            if state.draggingCursor { advanceCursor(state, to: touch.location(in: self).x) }
            finish(state)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            guard let state = active.removeValue(forKey: id) else { continue }
            pendingOrder.removeAll { $0 == id }
            state.timer?.invalidate()
            state.key.isPressed = false
            hidePopup()
            if state === cursorTouch { endCursorDrag() }
        }
    }

    private func finish(_ state: ActiveTouch) {
        state.timer?.invalidate()
        state.key.isPressed = false
        defer { hidePopup() }
        if state.showingAlternates {
            if let popup, popup.options.indices.contains(popup.selectedIndex) {
                delegate?.grid(self, didChooseAlternate: popup.options[popup.selectedIndex])
            }
            return
        }
        switch state.key.definition.action {
        case .backspace, .shift:
            break
        case .space:
            if state.draggingCursor {
                endCursorDrag()
            } else {
                delegate?.grid(self, didTrigger: .space)
            }
        default:
            delegate?.grid(self, didTrigger: state.key.definition.action)
        }
    }

    private func commitPendingCharacters() {
        for id in pendingOrder {
            guard let state = active[id], !state.showingAlternates, state.key.definition.isCharacter else { continue }
            active[id] = nil
            state.timer?.invalidate()
            state.key.isPressed = false
            delegate?.grid(self, didTrigger: state.key.definition.action)
            hidePopup()
        }
        pendingOrder.removeAll { active[$0] == nil }
    }

    private func cancelAllTouches() {
        active.values.forEach {
            $0.timer?.invalidate()
            $0.key.isPressed = false
        }
        active.removeAll()
        pendingOrder.removeAll()
        hidePopup()
        endCursorDrag()
    }

    // MARK: Popups

    private func showPreview(for key: KeyView) {
        hidePopup()
        let view = KeyPopupView(theme: theme)
        let isUpper = (key.definition.label != key.accessibilityLabel) && key.accessibilityLabel != nil
        view.configure(options: [isUpper ? (key.accessibilityLabel ?? key.definition.label) : key.definition.label], selected: 0, fontSize: 30)
        let width = max(key.frame.width + 14, 46)
        let height: CGFloat = 54
        var frame = CGRect(x: key.frame.midX - width / 2, y: key.frame.minY - height + 2, width: width, height: height)
        frame.origin.x = max(1, min(bounds.width - width - 1, frame.minX))
        view.frame = frame
        addSubview(view)
        popup = view
    }

    private func showAlternates(_ state: ActiveTouch) {
        hidePopup()
        state.showingAlternates = true
        delegate?.gridDidTouchDownKey(self)
        let key = state.key
        let base: String
        if case .character(let s) = key.definition.action { base = s } else { base = key.definition.label }
        let isUpper = key.accessibilityLabel == base.uppercased() && base != base.uppercased()
        let options = ([base] + key.definition.alternates).map { isUpper ? $0.uppercased() : $0 }
        let view = KeyPopupView(theme: theme)
        view.configure(options: options, selected: 0, fontSize: 22)
        let itemWidth: CGFloat = min(38, (bounds.width - 12) / CGFloat(options.count))
        let width = itemWidth * CGFloat(options.count) + 6
        let height: CGFloat = 48
        var frame = CGRect(x: key.frame.midX - itemWidth / 2 - 3, y: key.frame.minY - height + 2, width: width, height: height)
        frame.origin.x = max(2, min(bounds.width - width - 2, frame.minX))
        view.frame = frame
        addSubview(view)
        popup = view
    }

    private func hidePopup() {
        popup?.removeFromSuperview()
        popup = nil
    }
}
#endif
