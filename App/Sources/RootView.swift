import Platform
import Shell
import SwiftUI

/// The app's root screen: hosts the `AppComposition`'s feature-blind `ShellView`
/// and owns the `AppRouter` as a `@StateObject` so SwiftUI observes per-tab
/// navigation state for the lifetime of the scene.
///
/// (Phase 1's infrastructure-linkage probe lived here; it is gone now that the
/// real `Shell` is hosted — Task 12.)
struct RootView: View {
    @StateObject private var router: AppRouter
    @ObservedObject private var themeManager: AppThemeManager
    @ObservedObject private var localizationManager: AppLocalizationManager
    private let composition: AppComposition

    init(composition: AppComposition) {
        self.composition = composition
        _router = StateObject(wrappedValue: composition.router)
        _themeManager = ObservedObject(wrappedValue: composition.themeManager)
        _localizationManager = ObservedObject(wrappedValue: composition.localizationManager)
    }

    var body: some View {
        composition.rootView
            .id(localizationManager.currentLanguageCode)
            .environment(\.locale, Locale(identifier: localizationManager.currentLanguageCode))
            .environment(\.localizationManager, localizationManager)
            .environmentObject(router)
            .environmentObject(themeManager)
            .environmentObject(localizationManager)
            .preferredColorScheme(themeManager.colorScheme)
    }
}

#Preview {
    RootView(composition: AppComposition())
}
