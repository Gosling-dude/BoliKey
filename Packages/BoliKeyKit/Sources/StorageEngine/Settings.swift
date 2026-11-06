import Foundation

public enum LanguageMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case hinglish, english, hindi
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .hinglish: return "Hinglish"
        case .english: return "English"
        case .hindi: return "हिन्दी"
        }
    }
    public var indicator: String {
        switch self {
        case .hinglish: return "Hi-En"
        case .english: return "EN"
        case .hindi: return "हि"
        }
    }
    public var next: LanguageMode {
        switch self {
        case .hinglish: return .english
        case .english: return .hindi
        case .hindi: return .hinglish
        }
    }
}

public enum WritingStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case casual, professional, friendly, formal, short, playful
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .professional: return "Professional"
        case .friendly: return "Friendly"
        case .formal: return "Formal"
        case .short: return "Short"
        case .playful: return "Playful"
        }
    }
}

/// A user-selected way of writing. iOS never tells a keyboard who the recipient is,
/// so profiles are chosen by hand and stored only on this device.
public struct LanguageProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var language: LanguageMode
    public var style: WritingStyle

    public init(id: String = UUID().uuidString, name: String, language: LanguageMode, style: WritingStyle) {
        self.id = id
        self.name = name
        self.language = language
        self.style = style
    }

    public static let defaults: [LanguageProfile] = [
        .init(id: "friends", name: "College friends", language: .hinglish, style: .casual),
        .init(id: "work", name: "Professional", language: .english, style: .professional),
        .init(id: "family", name: "Family", language: .hinglish, style: .friendly),
        .init(id: "international", name: "International", language: .english, style: .friendly),
    ]
}

public struct KeyboardSettings: Codable, Equatable, Sendable {
    public var autoCorrectEnabled = true
    public var autoCapitalizeEnabled = true
    public var doubleSpacePeriodEnabled = true
    public var hapticsEnabled = true
    public var keyClickEnabled = true
    public var personalizationEnabled = true
    public var predictionsEnabled = true
    public var devanagariSuggestionsEnabled = false
    /// Offers an emoji in the suggestion bar for words such as "party" and "chai".
    public var emojiSuggestionsEnabled = true
    public var styleControlEnabled = true
    /// The keyboard's colours, by theme ID. An ID this version does not know shows Classic.
    public var keyboardTheme = "classic"
    public var languageMode: LanguageMode = .hinglish
    /// In Hindi, type in English letters on the usual keys and get Devanagari: namaste becomes नमस्ते.
    public var phoneticHindiEnabled = false
    public var activeProfileID: String = "friends"
    public var profiles: [LanguageProfile] = LanguageProfile.defaults
    public var onboardingCompleted = false
    /// Raised by the app on "Reset learning". The keyboard then wipes its own private copy.
    public var resetGeneration = 0
    /// Changed on every save from the app, so that a newer choice there beats an older one on the keyboard.
    public var revision = ""

    public init() {}

    public var activeProfile: LanguageProfile? { profiles.first { $0.id == activeProfileID } }

    // Tolerates missing keys, so a settings file from an older version still loads.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        autoCorrectEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoCorrectEnabled) ?? d.autoCorrectEnabled
        autoCapitalizeEnabled = try c.decodeIfPresent(Bool.self, forKey: .autoCapitalizeEnabled) ?? d.autoCapitalizeEnabled
        doubleSpacePeriodEnabled = try c.decodeIfPresent(Bool.self, forKey: .doubleSpacePeriodEnabled) ?? d.doubleSpacePeriodEnabled
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        keyClickEnabled = try c.decodeIfPresent(Bool.self, forKey: .keyClickEnabled) ?? d.keyClickEnabled
        personalizationEnabled = try c.decodeIfPresent(Bool.self, forKey: .personalizationEnabled) ?? d.personalizationEnabled
        predictionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .predictionsEnabled) ?? d.predictionsEnabled
        devanagariSuggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .devanagariSuggestionsEnabled) ?? d.devanagariSuggestionsEnabled
        emojiSuggestionsEnabled = try c.decodeIfPresent(Bool.self, forKey: .emojiSuggestionsEnabled) ?? d.emojiSuggestionsEnabled
        styleControlEnabled = try c.decodeIfPresent(Bool.self, forKey: .styleControlEnabled) ?? d.styleControlEnabled
        keyboardTheme = try c.decodeIfPresent(String.self, forKey: .keyboardTheme) ?? d.keyboardTheme
        languageMode = try c.decodeIfPresent(LanguageMode.self, forKey: .languageMode) ?? d.languageMode
        phoneticHindiEnabled = try c.decodeIfPresent(Bool.self, forKey: .phoneticHindiEnabled) ?? d.phoneticHindiEnabled
        activeProfileID = try c.decodeIfPresent(String.self, forKey: .activeProfileID) ?? d.activeProfileID
        profiles = try c.decodeIfPresent([LanguageProfile].self, forKey: .profiles) ?? d.profiles
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? d.onboardingCompleted
        resetGeneration = try c.decodeIfPresent(Int.self, forKey: .resetGeneration) ?? d.resetGeneration
        revision = try c.decodeIfPresent(String.self, forKey: .revision) ?? d.revision
    }
}
