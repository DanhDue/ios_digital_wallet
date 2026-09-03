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
    private let composition: AppComposition

    init(composition: AppComposition) {
        self.composition = composition
        _router = StateObject(wrappedValue: composition.router)
    }

    var body: some View {
        composition.rootView
            .environmentObject(router)
    }
}

#Preview {
    RootView(composition: AppComposition())
}
