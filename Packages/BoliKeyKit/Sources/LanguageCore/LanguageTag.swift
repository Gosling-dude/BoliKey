import Foundation

/// The language of a single token. Sentences are never forced into one language.
public enum LanguageTag: String, Codable, CaseIterable, Sendable {
    case english
    /// Hindi in Roman script, including Hinglish spellings.
    case hindiRoman
    case hindiDevanagari
    /// Numbers, punctuation and emoji, which carry no language.
    case neutral
    /// A script no installed language pack handles yet.
    case other

    public var isHindi: Bool { self == .hindiRoman || self == .hindiDevanagari }
}

public enum Script: Equatable, Sendable {
    case latin, devanagari, gurmukhi, bengali, gujarati, tamil, telugu, kannada, malayalam, digit, symbol

    /// Classifies a token by its first letter-like scalar.
    public static func of(_ token: String) -> Script {
        for scalar in token.unicodeScalars {
            switch scalar.value {
            case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F: return .latin
            case 0x900...0x97F: return .devanagari
            case 0x980...0x9FF: return .bengali
            case 0xA00...0xA7F: return .gurmukhi
            case 0xA80...0xAFF: return .gujarati
            case 0xB80...0xBFF: return .tamil
            case 0xC00...0xC7F: return .telugu
            case 0xC80...0xCFF: return .kannada
            case 0xD00...0xD7F: return .malayalam
            case 0x30...0x39: return .digit
            default: continue
            }
        }
        return .symbol
    }
}

/// Describes one language the keyboard can handle. Adding Punjabi, Bengali and the
/// others means adding a pack and its data files, with no engine changes for the
/// script-based routing below.
public struct LanguagePack: Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let indicator: String
    public let script: Script
    public let isAvailable: Bool

    public static let english = LanguagePack(id: "en", displayName: "English", indicator: "EN", script: .latin, isAvailable: true)
    public static let hinglish = LanguagePack(id: "hi-Latn", displayName: "Hinglish", indicator: "Hi-En", script: .latin, isAvailable: true)
    public static let hindi = LanguagePack(id: "hi", displayName: "हिन्दी", indicator: "हि", script: .devanagari, isAvailable: true)

    /// Planned packs. They are listed so routing is designed for them, and are not offered in the UI.
    public static let planned: [LanguagePack] = [
        .init(id: "pa", displayName: "ਪੰਜਾਬੀ", indicator: "ਪੰ", script: .gurmukhi, isAvailable: false),
        .init(id: "bn", displayName: "বাংলা", indicator: "বা", script: .bengali, isAvailable: false),
        .init(id: "mr", displayName: "मराठी", indicator: "म", script: .devanagari, isAvailable: false),
        .init(id: "gu", displayName: "ગુજરાતી", indicator: "ગુ", script: .gujarati, isAvailable: false),
        .init(id: "ta", displayName: "தமிழ்", indicator: "த", script: .tamil, isAvailable: false),
        .init(id: "te", displayName: "తెలుగు", indicator: "తె", script: .telugu, isAvailable: false),
        .init(id: "kn", displayName: "ಕನ್ನಡ", indicator: "ಕ", script: .kannada, isAvailable: false),
        .init(id: "ml", displayName: "മലയാളം", indicator: "മ", script: .malayalam, isAvailable: false),
    ]
}
