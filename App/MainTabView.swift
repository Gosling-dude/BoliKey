import SwiftUI
import BoliKeyKit
import KeyboardUI

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Try", systemImage: "keyboard") }
            DictionaryView().tabItem { Label("Dictionary", systemImage: "character.book.closed") }
            StylesView().tabItem { Label("Styles", systemImage: "wand.and.stars") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onChange(of: phase) { _, new in
            if new == .active { model.refreshData() }
        }
    }
}

struct HomeView: View {
    @State private var text = ""
    @State private var showingPreview = false
    @State private var secret = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        LogoMark(size: 56)
                        VStack(alignment: .leading) {
                            Text("BoliKey").font(.title2.bold())
                            Text("Type the way you talk.").foregroundStyle(.secondary)
                        }
                    }
                    GroupBox("Try it here") {
                        TextEditor(text: $text)
                            .focused($focused)
                            .frame(minHeight: 110)
                            .accessibilityIdentifier("try-field")
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Tap here, switch to BoliKey with the globe key, and type: bhai kal milte hai")
                                        .foregroundStyle(.secondary).padding(8).allowsHitTesting(false)
                                }
                            }
                    }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-uiTestSecureField") {
                        SecureField("Password", text: $secret).accessibilityIdentifier("secure-field")
                    }
                    #endif
                    Button { showingPreview = true } label: {
                        Label("Preview the keyboard without enabling it", systemImage: "eye")
                    }
                    .accessibilityIdentifier("open-preview")
                    if !focused {
                        GroupBox("Not set up yet?") { ActivationInstructions() }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }.accessibilityIdentifier("keyboard-done")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showingPreview) { KeyboardPreviewScreen() }
        }
    }
}

/// Runs the real keyboard view inside the app, on a private text buffer.
struct KeyboardPreviewScreen: View {
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    Text(text.isEmpty ? "Start typing on the keyboard below." : text)
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .accessibilityIdentifier("preview-text")
                }
                KeyboardPreview(text: $text).frame(height: 268)
            }
            .navigationTitle("Keyboard preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}

private struct KeyboardPreview: UIViewRepresentable {
    @Binding var text: String

    final class Coordinator {
        let proxy = StringTextProxy()
        var host: PreviewKeyboardHost?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let host = PreviewKeyboardHost(proxy: context.coordinator.proxy)
        context.coordinator.host = host
        let binding = $text
        context.coordinator.proxy.onChange = { binding.wrappedValue = $0 }
        let root = KeyboardRootView(host: host)
        root.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.12, alpha: 1) : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1) }
        root.willAppear()
        return root
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
