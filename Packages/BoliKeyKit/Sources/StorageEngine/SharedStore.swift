import Foundation

public enum BoliKeyIdentifiers {
    public static let appGroup = "group.com.sumitxfermi.bolikey"
}

/// JSON files shared between the app and the keyboard.
///
/// A keyboard without Full Access may be unable to write to the App Group container, and
/// must keep working regardless. So every read checks both places, and a failed shared
/// write lands in the extension's own private container instead.
public final class SharedStore {
    public enum Location: String { case shared, privateOnly }

    private let sharedDirectory: URL?
    private let privateDirectory: URL
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public init(sharedDirectory: URL?, privateDirectory: URL) {
        self.sharedDirectory = sharedDirectory
        self.privateDirectory = privateDirectory
        try? fileManager.createDirectory(at: privateDirectory, withIntermediateDirectories: true)
    }

    /// The store used by the real app and keyboard.
    public static func live(groupID: String = BoliKeyIdentifiers.appGroup) -> SharedStore {
        let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("BoliKey", isDirectory: true)
        let privateDir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("BoliKey", isDirectory: true)
        return SharedStore(sharedDirectory: shared, privateDirectory: privateDir)
    }

    public var hasSharedContainer: Bool { sharedDirectory != nil }

    /// Whether this process can actually write to the shared container right now.
    public func canWriteShared() -> Bool {
        guard let dir = sharedDirectory else { return false }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let probe = dir.appendingPathComponent(".write-probe")
        do {
            try Data().write(to: probe)
            try? fileManager.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    public func readShared<T: Decodable>(_ type: T.Type, file: String) -> T? {
        guard let dir = sharedDirectory else { return nil }
        return decode(type, at: dir.appendingPathComponent(file))
    }

    public func readPrivate<T: Decodable>(_ type: T.Type, file: String) -> T? {
        decode(type, at: privateDirectory.appendingPathComponent(file))
    }

    private func decode<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Writes to the shared container when possible and otherwise privately.
    /// `fileProtection` is left to `completeUntilFirstUserAuthentication` so typing works after unlock.
    @discardableResult
    public func write<T: Encodable>(_ value: T, file: String) -> Location? {
        guard let data = try? encoder.encode(value) else { return nil }
        if let dir = sharedDirectory {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            if (try? data.write(to: dir.appendingPathComponent(file), options: [.atomic])) != nil { return .shared }
        }
        if (try? data.write(to: privateDirectory.appendingPathComponent(file), options: [.atomic])) != nil { return .privateOnly }
        return nil
    }

    @discardableResult
    public func writePrivate<T: Encodable>(_ value: T, file: String) -> Bool {
        guard let data = try? encoder.encode(value) else { return false }
        return (try? data.write(to: privateDirectory.appendingPathComponent(file), options: [.atomic])) != nil
    }

    public func remove(file: String) {
        if let dir = sharedDirectory { try? fileManager.removeItem(at: dir.appendingPathComponent(file)) }
        try? fileManager.removeItem(at: privateDirectory.appendingPathComponent(file))
    }

    public func size(of file: String) -> Int {
        var total = 0
        for dir in [sharedDirectory, privateDirectory].compactMap({ $0 }) {
            let attrs = try? fileManager.attributesOfItem(atPath: dir.appendingPathComponent(file).path)
            total += (attrs?[.size] as? Int) ?? 0
        }
        return total
    }
}

public enum StoreFile {
    public static let settings = "settings.json"
    public static let dictionary = "dictionary.json"
    public static let learned = "learned.json"
    /// Settings the keyboard changed itself when it can only write privately.
    public static let keyboardState = "keyboard-state.json"
}

/// Loads settings the same way from the app and the keyboard.
public enum SettingsStore {
    public static func load(from store: SharedStore) -> KeyboardSettings {
        var settings = store.readShared(KeyboardSettings.self, file: StoreFile.settings)
            ?? store.readPrivate(KeyboardSettings.self, file: StoreFile.settings)
            ?? KeyboardSettings()
        // A choice made on the keyboard holds until the app saves something newer.
        if let state = store.readPrivate(KeyboardLocalState.self, file: StoreFile.keyboardState), state.basedOnRevision == settings.revision {
            settings.languageMode = state.languageMode ?? settings.languageMode
            settings.activeProfileID = state.activeProfileID ?? settings.activeProfileID
        }
        return settings
    }

    public static func save(_ settings: KeyboardSettings, to store: SharedStore) {
        var stamped = settings
        stamped.revision = UUID().uuidString
        store.write(stamped, file: StoreFile.settings)
    }
}

public struct KeyboardLocalState: Codable, Sendable {
    public var languageMode: LanguageMode?
    public var activeProfileID: String?
    public var basedOnRevision: String
    public init(languageMode: LanguageMode? = nil, activeProfileID: String? = nil, basedOnRevision: String) {
        self.languageMode = languageMode
        self.activeProfileID = activeProfileID
        self.basedOnRevision = basedOnRevision
    }
}
