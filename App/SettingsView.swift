import SwiftUI
import BoliKeyKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Keyboard") { KeyboardSettingsScreen() }.accessibilityIdentifier("settings-keyboard")
                    NavigationLink("Theme") { ThemeSettingsScreen() }.accessibilityIdentifier("settings-theme")
                    NavigationLink("Language") { LanguageSettingsScreen() }.accessibilityIdentifier("settings-language")
                    NavigationLink("AI Preferences") { AIPreferencesScreen() }.accessibilityIdentifier("settings-ai")
                    NavigationLink("Privacy") { PrivacyDashboardScreen() }.accessibilityIdentifier("settings-privacy")
                    NavigationLink("About BoliKey") { AboutScreen() }.accessibilityIdentifier("settings-about")
                }
                Section {
                    Button("Show Welcome Again") { model.settings.onboardingCompleted = false }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct KeyboardSettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section {
                Toggle("Fix Obvious Typos", isOn: $model.settings.autoCorrectEnabled).accessibilityIdentifier("toggle-autocorrect")
            } footer: {
                Text("Fixes only clear mistakes such as “teh”. Hinglish, names and words you added are left alone, and one backspace restores what you typed. Turn this off and BoliKey will only suggest, never change.")
            }
            Section("Suggestions") {
                Toggle("Show Suggestions", isOn: $model.settings.predictionsEnabled).accessibilityIdentifier("toggle-predictions")
                Toggle("Offer Devanagari for Hindi Words", isOn: $model.settings.devanagariSuggestionsEnabled)
                Toggle("Suggest Emoji", isOn: $model.settings.emojiSuggestionsEnabled).accessibilityIdentifier("toggle-emoji")
                Toggle("Show Writing Style Control", isOn: $model.settings.styleControlEnabled)
            }
            Section("Typing") {
                Toggle("Auto-Capitalisation", isOn: $model.settings.autoCapitalizeEnabled).accessibilityIdentifier("toggle-autocap")
                Toggle("“.” Shortcut", isOn: $model.settings.doubleSpacePeriodEnabled)
            }
            Section {
                Toggle("Vibrate on Key Press", isOn: $model.settings.hapticsEnabled)
                Toggle("Key Clicks", isOn: $model.settings.keyClickEnabled)
            } header: {
                Text("Feedback")
            } footer: {
                Text("iOS only allows these when Full Access is on.")
            }
        }
        .navigationTitle("Keyboard")
    }
}

private struct LanguageSettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LanguagePicker(selection: $model.settings.languageMode)
                Text("Each word is recognised on its own, so English and Hindi can mix in one sentence whichever you choose. This choice sets which predictions come first.")
                    .font(.footnote).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Type Hindi in English Letters", isOn: $model.settings.phoneticHindiEnabled)
                        .accessibilityIdentifier("toggle-phonetic-hindi")
                    Text("In Hindi, the keyboard shows the English keys. Type namaste and it becomes नमस्ते when the word ends. One backspace right after brings back what you typed, and the Hindi spelling you pick is remembered.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
                Text("Planned: \(LanguagePack.planned.map(\.displayName).joined(separator: ", "))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Language")
    }
}

private struct AIPreferencesScreen: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section {
                Toggle("Writing Style Control", isOn: $model.settings.styleControlEnabled)
            } footer: {
                Text("Adds the wand to the keyboard, which offers rewrites of your sentence. It only runs when you tap it.")
            }
            Section("How it works today") {
                LabeledContent("Predictions", value: "Statistical, on device")
                LabeledContent("Language detection", value: "Statistical, on device")
                LabeledContent("Writing styles", value: "Rules, on device")
                LabeledContent("Cloud AI", value: "Not included")
            }
            Section {
                Text("This version has no cloud AI and no network code. A future AI rewriter would be off by default and would only run when you ask it to, never while you type.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AI Preferences")
    }
}

private struct PrivacyDashboardScreen: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmingReset = false
    @State private var confirmingClear = false

    var body: some View {
        Form {
            Section {
                Label("Nothing you type leaves this iPhone.", systemImage: "lock.shield.fill").font(.headline)
                Text("BoliKey has no network code, no analytics and no account. Password fields are never read: iOS replaces third-party keyboards there.")
                    .font(.subheadline)
            }
            Section {
                ForEach(model.inventory) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        LabeledContent(item.title, value: "\(item.count)")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(item.title)
                            .accessibilityValue("\(item.count)")
                            .accessibilityIdentifier("inventory-\(item.id)")
                        Text(item.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Stored on this iPhone")
            } footer: {
                Text("BoliKey learns only from suggestions you tap and corrections you undo, never from what you simply type. Without Full Access the keyboard keeps what it learns to itself, so these counts can read lower than the real amount. Reset still erases it, the next time the keyboard opens.")
            }
            Section {
                Toggle("Learn From My Choices", isOn: $model.settings.personalizationEnabled)
                    .accessibilityIdentifier("toggle-personalization")
            }
            Section {
                Button("Reset Learning") { confirmingReset = true }
                    .accessibilityIdentifier("privacy-reset")
                Button("Clear All My Data", role: .destructive) { confirmingClear = true }
                    .accessibilityIdentifier("privacy-clear")
            } footer: {
                Text("Reset erases what was learned and keeps your dictionary. Clear erases both.")
            }
            Section("Full Access") {
                Button("Open iPhone Settings") { model.openSystemSettings() }
            }
        }
        .navigationTitle("Privacy")
        .onAppear { model.refreshData() }
        .confirmationDialog("Erase everything BoliKey has learned?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset Learning", role: .destructive) { model.resetLearning() }
        }
        .confirmationDialog("Erase learning and your personal dictionary?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Clear All My Data", role: .destructive) { model.clearAllData() }
        }
    }
}

private struct AboutScreen: View {
    private var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    LogoMark(size: 80)
                    Text("BoliKey").font(.title.bold())
                    Text("Type the way you talk.").foregroundStyle(.secondary)
                    Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            Section("Why BoliKey") {
                Text("People mix languages when they talk. A keyboard should adapt to you, not make you adapt to it.")
            }
            Section("Language data") {
                Text("English word frequencies from FrequencyWords (CC BY-SA 4.0). Example sentences from Tatoeba (CC BY 2.0 FR). Hinglish vocabulary written for BoliKey.")
                    .font(.footnote)
            }
        }
        .navigationTitle("About")
    }
}
