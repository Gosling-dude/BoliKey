import SwiftUI
import BoliKeyKit

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch step {
                case 0: WelcomeStep { step = 1 }
                case 1: ActivationStep { step = 2 }
                default: LanguageStep { model.settings.onboardingCompleted = true }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: step)
        }
    }
}

private struct WelcomeStep: View {
    let next: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            LogoMark(size: 104)
            Text("BoliKey").font(.system(size: 40, weight: .bold, design: .rounded))
            Text("Type the way you talk.").font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 18) {
                FeatureRow(symbol: "text.bubble", title: "Understands Hinglish", detail: "“bhai kal milte hai” stays exactly as you wrote it.")
                FeatureRow(symbol: "hand.raised", title: "You stay in charge", detail: "Better spellings and phrasing are offered. You decide.")
                FeatureRow(symbol: "lock.shield", title: "Private by design", detail: "Everything runs on your iPhone, even with no internet.")
            }
            .padding(.top, 12)
            Spacer()
            PrimaryButton(title: "Get Started", identifier: "onboarding-start", action: next)
        }
        .padding(24)
    }
}

private struct ActivationStep: View {
    @EnvironmentObject private var model: AppModel
    let next: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add BoliKey to your keyboards").font(.title.bold())
                ActivationInstructions()
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button("Open Settings") { model.openSystemSettings() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("open-settings")
                PrimaryButton(title: "Continue", identifier: "onboarding-continue", action: next)
            }
            .padding(24)
            .background(.bar)
        }
    }
}

/// Shared between onboarding and the home screen.
struct ActivationInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Brand.indigo))
                    Text(text).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Then, in any app, touch and hold the globe key under your keyboard and choose BoliKey.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About “Allow Full Access”").font(.headline)
                    Text("BoliKey works without it: typing, Hinglish suggestions, corrections and your dictionary all run on your iPhone.")
                    Text("Turn it on only if you want key vibrations and key clicks, and to let this app show and manage what the keyboard has learned.")
                    Text("iOS shows a strong warning for every keyboard, because Full Access would let a keyboard use the network. BoliKey contains no network code and sends nothing, whichever you choose.")
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var steps: [String] {
        ["Open the iPhone Settings app.", "Go to General, then Keyboard.", "Tap Keyboards, then Add New Keyboard.", "Choose BoliKey from the list."]
    }
}

private struct LanguageStep: View {
    @EnvironmentObject private var model: AppModel
    let done: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How do you usually type?").font(.title.bold())
            Text("You can switch any time with the language button on the keyboard.").foregroundStyle(.secondary)
            LanguagePicker(selection: $model.settings.languageMode)
            Spacer()
            PrimaryButton(title: "Start Typing", identifier: "onboarding-finish", action: done)
        }
        .padding(24)
    }
}

struct LanguagePicker: View {
    @Binding var selection: LanguageMode
    var body: some View {
        VStack(spacing: 10) {
            ForEach(LanguageMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName).font(.headline)
                            Text(detail(mode)).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selection == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection == mode ? Brand.accent : .secondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("language-\(mode.rawValue)")
                .accessibilityAddTraits(selection == mode ? .isSelected : [])
            }
        }
    }

    private func detail(_ mode: LanguageMode) -> String {
        switch mode {
        case .hinglish: return "Hindi in English letters, mixed with English"
        case .english: return "English first. Hindi words are still respected"
        case .hindi: return "Devanagari keyboard and suggestions"
        }
    }
}

struct LogoMark: View {
    let size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
            .fill(Brand.gradient)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "bubble.fill")
                    .font(.system(size: size * 0.62))
                    .foregroundStyle(.white)
                    .overlay {
                        Text("ब").font(.system(size: size * 0.34, weight: .semibold)).foregroundStyle(Brand.indigo).offset(y: -size * 0.02)
                    }
            }
            .accessibilityHidden(true)
    }
}

struct FeatureRow: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Brand.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.indigo)
        .accessibilityIdentifier(identifier)
    }
}
