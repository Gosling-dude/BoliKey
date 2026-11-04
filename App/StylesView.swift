import SwiftUI
import BoliKeyKit

struct StylesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var sample = "kal meeting hai kya"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Type a sentence", text: $sample)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("style-sample")
                    ForEach(model.engine.writing.rewrites(of: sample), id: \.style) { rewrite in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rewrite.style.displayName).font(.caption.bold()).foregroundStyle(Brand.accent)
                            Text(rewrite.text).accessibilityIdentifier("style-result-\(rewrite.style.rawValue)")
                        }
                    }
                } header: {
                    Text("See how it sounds")
                } footer: {
                    Text("Tap the wand on the keyboard to get these for what you are writing. Nothing changes until you pick one. These rules cover common sentences. When a Hinglish sentence is not covered, BoliKey adjusts its tone and does not translate it.")
                }
                Section {
                    ForEach($model.settings.profiles) { $profile in
                        NavigationLink {
                            ProfileEditor(profile: $profile)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(profile.name)
                                    Text("\(profile.language.displayName), \(profile.style.displayName)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.settings.activeProfileID == profile.id {
                                    Image(systemName: "checkmark").foregroundStyle(Brand.accent).accessibilityLabel("Active")
                                }
                            }
                        }
                        .accessibilityIdentifier("profile-\(profile.id)")
                    }
                    .onDelete { model.settings.profiles.remove(atOffsets: $0) }
                    Button("Add Profile") {
                        model.settings.profiles.append(LanguageProfile(name: "New profile", language: .hinglish, style: .casual))
                    }
                    .accessibilityIdentifier("profile-add")
                } header: {
                    Text("Conversation profiles")
                } footer: {
                    Text("iOS does not tell keyboards who you are writing to, so you choose the profile yourself, here or from the wand on the keyboard. Profiles stay on this iPhone.")
                }
            }
            .navigationTitle("Writing Styles")
        }
    }
}

private struct ProfileEditor: View {
    @EnvironmentObject private var model: AppModel
    @Binding var profile: LanguageProfile

    var body: some View {
        Form {
            TextField("Name", text: $profile.name)
            Picker("Language", selection: $profile.language) {
                ForEach(LanguageMode.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Style", selection: $profile.style) {
                ForEach(WritingStyle.allCases) { Text($0.displayName).tag($0) }
            }
            Button("Use This Profile") {
                model.settings.activeProfileID = profile.id
                model.settings.languageMode = profile.language
            }
        }
        .navigationTitle(profile.name)
    }
}
