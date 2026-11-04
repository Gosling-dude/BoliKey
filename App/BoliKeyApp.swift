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
        }
    }
}
