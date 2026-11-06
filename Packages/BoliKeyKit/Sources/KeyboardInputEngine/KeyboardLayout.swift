import Foundation

public enum KeyAction: Equatable, Hashable, Sendable {
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    case page(KeyboardPage)
    case nextKeyboard
}

public enum KeyboardPage: Equatable, Hashable, Sendable {
    case letters, numbers, symbols, devanagari, devanagariAlt, emoji
}

public struct KeyDefinition: Equatable, Hashable, Sendable {
    public let action: KeyAction
    public let label: String
    /// Relative width within its row. A letter key is 1.
    public let width: CGFloat
    public let alternates: [String]
    public let accessibilityLabel: String

    public init(action: KeyAction, label: String, width: CGFloat = 1, alternates: [String] = [], accessibilityLabel: String? = nil) {
        self.action = action
        self.label = label
        self.width = width
        self.alternates = alternates
        self.accessibilityLabel = accessibilityLabel ?? label
    }

    public var isCharacter: Bool {
        if case .character = action { return true }
        return false
    }
}

public enum KeyboardLayouts {
    private static let alternates: [String: [String]] = [
        "a": ["ā", "à", "á", "â", "ä", "ã"], "e": ["ē", "è", "é", "ê", "ë"], "i": ["ī", "ì", "í", "î", "ï"],
        "o": ["ō", "ò", "ó", "ô", "ö", "õ"], "u": ["ū", "ù", "ú", "û", "ü"], "n": ["ñ", "ń", "ṇ"], "s": ["ś", "ṣ", "ß"],
        "c": ["ç", "ć", "č"], "y": ["ÿ", "ý"], "z": ["ž", "ź"], "d": ["ḍ"], "t": ["ṭ"], "r": ["ṛ"],
        ".": [",", "?", "!", "'", "\"", ":", ";"], "-": ["–", "—", "•"], "/": ["\\"], "$": ["₹", "€", "£", "¥"], "₹": ["$", "€", "£", "¥"],
        "0": ["°"], "\"": ["“", "”", "«", "»"], "'": ["‘", "’", "`"], "?": ["¿"], "!": ["¡"], "&": ["§"], "%": ["‰"],
        "क": ["क़", "क्ष", "क्"], "ख": ["ख़"], "ग": ["ग़", "ज्ञ"], "ज": ["ज़", "ज्ञ"], "ड": ["ड़"], "ढ": ["ढ़"], "फ": ["फ़"], "त": ["त्र", "त्"],
        "स": ["श्र", "स्"], "र": ["ऋ", "ृ"], "न": ["ण", "ञ", "ङ"], "श": ["ष", "श्र"], "ं": ["ँ", "ः"], "।": ["॥", ".", ",", "?", "!"], "ा": ["आ"], "ि": ["इ"], "ी": ["ई"], "ु": ["उ"], "ू": ["ऊ"], "े": ["ए"], "ै": ["ऐ"], "ो": ["ओ"], "ौ": ["औ"],
    ]

    private static func row(_ characters: String, uppercase: Bool = false) -> [KeyDefinition] {
        characters.map { ch in
            let s = String(ch)
            return KeyDefinition(action: .character(s), label: uppercase ? s.uppercased() : s, alternates: alternates[s] ?? [])
        }
    }

    public static func rows(for page: KeyboardPage, uppercase: Bool) -> [[KeyDefinition]] {
        switch page {
        case .letters:
            return [
                row("qwertyuiop", uppercase: uppercase),
                row("asdfghjkl", uppercase: uppercase),
                [KeyDefinition(action: .shift, label: "shift", width: 1.4, accessibilityLabel: "Shift")]
                    + row("zxcvbnm", uppercase: uppercase)
                    + [KeyDefinition(action: .backspace, label: "delete", width: 1.4, accessibilityLabel: "Delete")],
            ]
        case .numbers:
            return [
                row("1234567890"),
                row("-/:;()₹&@\""),
                [KeyDefinition(action: .page(.symbols), label: "#+=", width: 1.4, accessibilityLabel: "More symbols")]
                    + row(".,?!'").map { key in
                        KeyDefinition(action: key.action, label: key.label, width: 1.4, alternates: key.alternates)
                    }
                    + [KeyDefinition(action: .backspace, label: "delete", width: 1.4, accessibilityLabel: "Delete")],
            ]
        case .symbols:
            return [
                row("[]{}#%^*+="),
                row("_\\|~<>$€£•"),
                [KeyDefinition(action: .page(.numbers), label: "123", width: 1.4, accessibilityLabel: "Numbers")]
                    + row(".,?!'").map { key in
                        KeyDefinition(action: key.action, label: key.label, width: 1.4, alternates: key.alternates)
                    }
                    + [KeyDefinition(action: .backspace, label: "delete", width: 1.4, accessibilityLabel: "Delete")],
            ]
        case .devanagari:
            return [
                devaRow(["ो", "े", "्", "ि", "ु", "प", "र", "क", "त", "च", "ट"]),
                devaRow(["ं", "म", "न", "व", "ल", "स", "य", "ब", "ह", "ग", "द"]),
                [KeyDefinition(action: .page(.devanagariAlt), label: "अ॰", width: 1.3, accessibilityLabel: "More Hindi letters")]
                    + devaRow(["ा", "ी", "ू", "ज", "ड", "ै", "ौ", "।"])
                    + [KeyDefinition(action: .backspace, label: "delete", width: 1.3, accessibilityLabel: "Delete")],
            ]
        case .devanagariAlt:
            return [
                devaRow(["अ", "आ", "इ", "ई", "उ", "ऊ", "ए", "ऐ", "ओ", "औ", "ऋ"]),
                devaRow(["ख", "घ", "छ", "झ", "ठ", "ढ", "थ", "ध", "फ", "भ", "ण"]),
                [KeyDefinition(action: .page(.devanagari), label: "क॰", width: 1.3, accessibilityLabel: "Main Hindi letters")]
                    + devaRow(["श", "ष", "ञ", "ङ", "ृ", "ँ", "ः", "़"])
                    + [KeyDefinition(action: .backspace, label: "delete", width: 1.3, accessibilityLabel: "Delete")],
            ]
        case .emoji:
            return []
        }
    }

    private static func devaRow(_ letters: [String]) -> [KeyDefinition] {
        letters.map { KeyDefinition(action: .character($0), label: $0, alternates: alternates[$0] ?? []) }
    }

    /// The bottom row. The globe only appears when iOS says the keyboard must provide one.
    public static func bottomRow(page: KeyboardPage, needsGlobe: Bool, returnLabel: String, spaceLabel: String, base: KeyboardPage) -> [KeyDefinition] {
        var keys: [KeyDefinition] = []
        switch page {
        case .letters, .devanagari, .devanagariAlt:
            keys.append(KeyDefinition(action: .page(.numbers), label: "123", width: 1.5, accessibilityLabel: "Numbers"))
        default:
            keys.append(KeyDefinition(action: .page(base), label: base == .letters ? "ABC" : "अ", width: 1.5, accessibilityLabel: "Letters"))
        }
        if needsGlobe {
            keys.append(KeyDefinition(action: .nextKeyboard, label: "globe", width: 1.2, accessibilityLabel: "Next keyboard"))
        }
        keys.append(KeyDefinition(action: .page(.emoji), label: "emoji", width: 1.2, accessibilityLabel: "Emoji"))
        keys.append(KeyDefinition(action: .space, label: spaceLabel, width: needsGlobe ? 3.7 : 4.9, accessibilityLabel: "Space"))
        keys.append(KeyDefinition(action: .returnKey, label: returnLabel, width: 2.0, accessibilityLabel: returnLabel))
        return keys
    }

    /// The bottom row while searching for emoji: back to the emoji panel, a space for the query,
    /// and back to the letters. It has the same total width as the usual row.
    public static func emojiSearchBottomRow(needsGlobe: Bool) -> [KeyDefinition] {
        var keys = [KeyDefinition(action: .page(.emoji), label: "emoji", width: 1.5, accessibilityLabel: "Emoji")]
        if needsGlobe {
            keys.append(KeyDefinition(action: .nextKeyboard, label: "globe", width: 1.2, accessibilityLabel: "Next keyboard"))
        }
        keys.append(KeyDefinition(action: .space, label: "space", width: needsGlobe ? 4.9 : 6.1, accessibilityLabel: "Space"))
        keys.append(KeyDefinition(action: .page(.letters), label: "ABC", width: 2.0, accessibilityLabel: "Done searching"))
        return keys
    }
}

public enum EmojiCatalog {
    public struct Category: Sendable {
        public let name: String
        public let symbol: String
        public let emoji: [String]
        public init(name: String, symbol: String, emoji: [String]) {
            self.name = name
            self.symbol = symbol
            self.emoji = emoji
        }
    }

    /// Every emoji in the panel, once each.
    public static let allEmoji: [String] = {
        var seen = Set<String>()
        return categories.flatMap(\.emoji).filter { seen.insert($0).inserted }
    }()

    public static let categories: [Category] = [
        .init(name: "Smileys", symbol: "😀", emoji: "😀 😃 😄 😁 😆 😅 🤣 😂 🙂 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🥵 🥶 🥴 😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 💀 💩 🤡 👻 👽 🤖".split(separator: " ").map(String.init)),
        .init(name: "Gestures", symbol: "👍", emoji: "👍 👎 👌 🤌 🤏 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 🙏 🤝 👏 🙌 👐 🤲 💪 🦾 ✍️ 💅 🤳 👀 👁️ 🧠 🫶 🙇 🤦 🤷 💁 🙋 🙆 🙅 🏃 🚶 💃 🕺".split(separator: " ").map(String.init)),
        .init(name: "Hearts", symbol: "❤️", emoji: "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 💋 💯 💢 💥 💫 💦 💨 🔥 ✨ ⭐ 🌟 🎉 🎊 🎈 🎁 🏆 🥇".split(separator: " ").map(String.init)),
        .init(name: "Food", symbol: "🍕", emoji: "☕ 🍵 🥤 🍺 🍻 🥂 🍾 🍷 🍹 🍕 🍔 🍟 🌭 🥪 🌮 🌯 🍜 🍝 🍛 🍚 🍙 🍱 🍲 🥘 🍳 🥗 🍿 🧂 🥟 🍰 🎂 🧁 🍫 🍬 🍭 🍩 🍪 🍦 🍎 🍌 🍉 🍇 🍓 🥭 🍍 🥥".split(separator: " ").map(String.init)),
        .init(name: "Places", symbol: "🚗", emoji: "🚗 🚕 🛺 🚌 🚓 🚑 🏍️ 🛵 🚲 🚆 🚇 ✈️ 🚀 🏠 🏢 🏫 🏥 🏦 🏨 🛕 🕌 ⛪ 🏖️ ⛰️ 🌄 🌅 🌃 🌧️ ⛈️ ☀️ 🌙 ⭐ 🌈 ❄️ 🌊".split(separator: " ").map(String.init)),
        .init(name: "Objects", symbol: "📱", emoji: "📱 💻 ⌨️ 🖥️ 🎧 📷 📹 📺 🎮 🕹️ 📚 📖 ✏️ 📝 📌 📎 📅 ⏰ ⌛ 💰 💵 💳 🔑 🔒 💡 🔋 🛒 🎵 🎶 🎤 🎬 ⚽ 🏏 🏀 🏸 🎯 💊 🩺 🪔 🎆 🧨 🎨 💍".split(separator: " ").map(String.init)),
        .init(name: "Flags", symbol: "🇮🇳", emoji: "🇮🇳 🏳️ 🏴 🏁 🚩 🇺🇸 🇬🇧 🇦🇪 🇨🇦 🇦🇺 🇸🇬 🇳🇵 🇧🇩 🇱🇰 🇯🇵 🇩🇪 🇫🇷".split(separator: " ").map(String.init)),
    ]
}
