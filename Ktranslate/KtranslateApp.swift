import SwiftUI

@main
struct KtranslateApp: App {
    @AppStorage("settings_theme") private var selectedThemeRawValue: String = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            MainView() // Assuming MainView is your primary content view
                .preferredColorScheme(currentScheme)
        }
    }

    var currentScheme: ColorScheme? {
        let theme = AppTheme(rawValue: selectedThemeRawValue) ?? .system
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Uses the system's current scheme
        }
    }
}
