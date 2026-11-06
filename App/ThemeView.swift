import SwiftUI
import BoliKeyKit

/// Picks the keyboard's colours. The keyboard reads the choice the next time it opens.
struct ThemeSettingsScreen: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var showingPreview = false
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(KeyboardPalette.all) { palette in
                        let selected = model.settings.keyboardTheme == palette.id
                        Button {
                            model.settings.keyboardTheme = palette.id
                        } label: {
                            ThemeCard(palette: palette, dark: scheme == .dark, selected: selected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(palette.name). \(palette.detail)")
                        .accessibilityValue(selected ? "Selected" : "")
                        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("theme-\(palette.id)")
                    }
                }
                Button {
                    showingPreview = true
                } label: {
                    Label("Try It on the Keyboard", systemImage: "keyboard")
                }
                .accessibilityIdentifier("theme-try")
                Text("The keyboard changes the next time it opens. Classic follows light and dark mode, and the other themes keep their colours in both.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Theme")
        .sheet(isPresented: $showingPreview) { KeyboardPreviewScreen() }
    }
}

private struct ThemeCard: View {
    let palette: KeyboardPalette
    let dark: Bool
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MiniKeyboard(colors: palette.colors(dark: dark))
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Brand.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
                }
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(palette.name).font(.subheadline.bold())
                    Text(palette.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
                }
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.accent)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// A drawing of the keyboard in a theme's colours: the suggestion strip, three rows of keys,
/// and the bottom row with an accented return key.
private struct MiniKeyboard: View {
    let colors: KeyboardColors

    private func color(_ c: RGBA) -> Color {
        let solid = c.over(colors.previewBackground)
        return Color(red: solid.r, green: solid.g, blue: solid.b)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Capsule().fill(color(RGBA(colors.accent.r, colors.accent.g, colors.accent.b, 0.18)))
                    .frame(width: 20, height: 9)
                    .overlay { Text("Hi").font(.system(size: 6, weight: .bold)).foregroundStyle(color(colors.accent)) }
                Text("kal milte hai").font(.system(size: 7)).foregroundStyle(color(colors.suggestionText))
                Spacer(minLength: 0)
            }
            .frame(height: 12)
            ForEach([10, 9, 7], id: \.self) { count in
                HStack(spacing: 2.5) {
                    ForEach(0..<count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color(colors.key))
                    }
                }
                .padding(.horizontal, count == 10 ? 0 : CGFloat(10 - count) * 3)
            }
            HStack(spacing: 2.5) {
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color(colors.functionKey)).frame(maxWidth: 18)
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color(colors.key))
                    .overlay { Text("BoliKey").font(.system(size: 5)).foregroundStyle(color(colors.keyText)) }
                RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color(colors.accent)).frame(maxWidth: 24)
                    .overlay { Text("send").font(.system(size: 5, weight: .semibold)).foregroundStyle(color(colors.accentText)) }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color(colors.previewBackground))
        .accessibilityHidden(true)
    }
}
