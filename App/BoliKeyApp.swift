import SwiftUI

@main
struct BoliKeyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.settings.onboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(model)
            .tint(Brand.accent)
            #if DEBUG
            // simctl's appearance switch does not reach apps on this simulator runtime, so UI tests ask directly.
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uiTestDark") ? .dark : nil)
            #endif
        }
    }
}
