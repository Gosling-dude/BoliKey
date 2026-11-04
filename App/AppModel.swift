import SwiftUI
import BoliKeyKit

enum Brand {
    static let accent = Color("AccentColor")
    static let indigo = Color(red: 0.20, green: 0.18, blue: 0.56)
    static let saffron = Color(red: 1.00, green: 0.55, blue: 0.20)
    static let gradient = LinearGradient(colors: [indigo, Color(red: 0.42, green: 0.20, blue: 0.62), saffron],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Owns settings and personal data for the companion app. Every change is written straight to
/// the App Group, where the keyboard reads it the next time it appears.
@MainActor
final class AppModel: ObservableObject {
    let store: SharedStore
    let engine: BoliKeyEngine
    @Published private(set) var dictionary: [VocabularyEntry] = []
    @Published private(set) var inventory: [DataInventoryItem] = []
    @Published var settings: KeyboardSettings {
        didSet {
            guard settings != oldValue else { return }
            SettingsStore.save(settings, to: store)
            engine.settings = settings
            refreshData()
        }
    }

    init() {
        let store = SharedStore.live()
        self.store = store
        var loaded = SettingsStore.load(from: store)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uiTestResetData") {
            for file in [StoreFile.settings, StoreFile.dictionary, StoreFile.learned, StoreFile.keyboardState] { store.remove(file: file) }
            loaded = KeyboardSettings()
        }
        if args.contains("-uiTestSkipOnboarding") { loaded.onboardingCompleted = true }
        SettingsStore.save(loaded, to: store)
        #endif
        settings = loaded
        engine = BoliKeyEngine(store: store, settings: loaded)
        refreshData()
    }

    func refreshData() {
        engine.personalization.reload()
        dictionary = engine.personalization.dictionary
        inventory = PrivacyManager.inventory(personal: engine.personalization)
    }

    func addVocabulary(text: String, kind: VocabularyEntry.Kind, expansion: String?) {
        engine.personalization.add(VocabularyEntry(text: text, kind: kind, expansion: expansion))
        refreshData()
    }

    func removeVocabulary(_ entry: VocabularyEntry) {
        engine.personalization.remove(entry)
        refreshData()
    }

    /// Raises the generation as well, so a keyboard holding private data wipes it too.
    func resetLearning() {
        settings.resetGeneration += 1
        engine.personalization.resetLearning(generation: settings.resetGeneration)
        refreshData()
    }

    func clearAllData() {
        settings.resetGeneration += 1
        engine.personalization.clearAll(generation: settings.resetGeneration)
        refreshData()
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
