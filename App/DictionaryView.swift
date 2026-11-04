import SwiftUI
import BoliKeyKit

struct DictionaryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var text = ""
    @State private var kind: VocabularyEntry.Kind = .word
    @State private var expansion = ""

    private var canAdd: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
            && (kind != .abbreviation || !expansion.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Word, name or phrase", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("dictionary-text")
                    Picker("Type", selection: $kind) {
                        ForEach(VocabularyEntry.Kind.allCases) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityIdentifier("dictionary-kind")
                    if kind == .abbreviation {
                        TextField("Expands to", text: $expansion)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("dictionary-expansion")
                    }
                    Button("Add to Dictionary") {
                        model.addVocabulary(text: text, kind: kind, expansion: kind == .abbreviation ? expansion : nil)
                        text = ""
                        expansion = ""
                    }
                    .disabled(!canAdd)
                    .accessibilityIdentifier("dictionary-add")
                } header: {
                    Text("Add")
                } footer: {
                    Text("BoliKey never corrects these words, and suggests them as you type.")
                }
                Section("Your words") {
                    if model.dictionary.isEmpty {
                        Text("Nothing here yet. Try a nickname, or your spelling of a word.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(model.dictionary) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.text).accessibilityIdentifier("dictionary-entry-\(entry.id)")
                            Text(subtitle(entry)).font(.caption).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) { model.removeVocabulary(entry) }
                        }
                    }
                }
            }
            .navigationTitle("Dictionary")
        }
    }

    private func subtitle(_ entry: VocabularyEntry) -> String {
        if let expansion = entry.expansion { return "\(entry.kind.displayName), expands to “\(expansion)”" }
        return entry.kind.displayName
    }
}
