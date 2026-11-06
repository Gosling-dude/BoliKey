import Foundation
import StorageEngine
import PersonalizationEngine

/// The text field traits that matter for privacy.
public struct FieldContext: Equatable, Sendable {
    public var isSecure: Bool
    public var isSensitiveKind: Bool

    public init(isSecure: Bool = false, isSensitiveKind: Bool = false) {
        self.isSecure = isSecure
        self.isSensitiveKind = isSensitiveKind
    }
}

public struct FieldPolicy: Equatable, Sendable {
    public let mayReadContext: Bool
    public let mayPredict: Bool
    public let mayLearn: Bool
    public let mayAutoCorrect: Bool

    public static let full = FieldPolicy(mayReadContext: true, mayPredict: true, mayLearn: true, mayAutoCorrect: true)
    /// Passwords and one-time codes. The keyboard types characters and does nothing else.
    public static let keysOnly = FieldPolicy(mayReadContext: false, mayPredict: false, mayLearn: false, mayAutoCorrect: false)
    /// URLs, emails, numeric fields.
    public static let noLanguage = FieldPolicy(mayReadContext: true, mayPredict: false, mayLearn: false, mayAutoCorrect: false)
}

public struct DataInventoryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let count: Int
}

public enum PrivacyManager {
    public static func policy(for field: FieldContext) -> FieldPolicy {
        if field.isSecure { return .keysOnly }
        if field.isSensitiveKind { return .noLanguage }
        return .full
    }

    /// Exactly what is stored on this device, in the words the dashboard shows.
    public static func inventory(personal: PersonalizationEngine) -> [DataInventoryItem] {
        let learned = personal.learned
        return [
            .init(id: "dictionary", title: "Personal dictionary", detail: "Words, names and phrases you added yourself.", count: personal.dictionary.count),
            .init(id: "words", title: "Learned words", detail: "Words from suggestions you tapped, with how often you chose them.", count: learned.wordCounts.count),
            .init(id: "pairs", title: "Learned word pairs", detail: "Two-word sequences from suggestions you tapped.", count: learned.bigramCounts.count),
            .init(id: "phrases", title: "Learned phrases", detail: "Full phrases you tapped in the suggestion bar.", count: learned.phraseCounts.count),
            .init(id: "spellings", title: "Preferred spellings", detail: "Your spelling of a word, such as nhi for nahi.", count: learned.preferredSpellings.count),
            .init(id: "hindi", title: "Hindi spellings you chose", detail: "How a word typed in English letters should appear in Hindi, such as सीता for sita.", count: learned.hindiSpellings.count),
            .init(id: "rejections", title: "Undone corrections", detail: "Autocorrections you reversed, so they are not repeated.", count: learned.rejectedCorrections.count),
            .init(id: "emoji", title: "Recent emoji", detail: "Emoji you picked, shown first in the emoji panel.", count: learned.recentEmoji.count),
        ]
    }
}
