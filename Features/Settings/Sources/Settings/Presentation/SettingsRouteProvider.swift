import Platform
import SwiftUI

/// The Settings feature's contribution to `AppRouter` (Source Spec §4.3).
///
/// The `App` composition root registers one instance; the router calls
/// `canHandle` to match `AppRoutes.SettingsRoot` and `destination(for:)` for the
/// screen. The ViewModel is built by an injected `@MainActor` closure; in
/// production this is `{ SettingsViewModel() }` which auto-resolves dependencies
/// via `Factory.Container`.
///
/// The `RouteProvider` requirements are `nonisolated`; `destination(for:)`
/// therefore hands back a tiny `DeferredSettingsView` whose SwiftUI `body`
/// (`@MainActor` by construction) is where the `@MainActor` ViewModel and
/// `SettingsView` are actually built. This keeps the conformance unisolated —
/// no `MainActor.assumeIsolated` (iOS 17+ only) needed — and satisfies
/// ArchTests K5's plain-`RouteProvider` conformance check.
public final class SettingsRouteProvider: RouteProvider {
    private let makeViewModel: @MainActor () -> SettingsViewModel

    public init(makeViewModel: @escaping @MainActor () -> SettingsViewModel) {
        self.makeViewModel = makeViewModel
    }

    public func canHandle(_ route: any AppRoute) -> Bool {
        route is AppRoutes.SettingsRoot
    }

    public func destination(for route: any AppRoute) -> AnyView {
        guard route is AppRoutes.SettingsRoot else {
            return AnyView(EmptyView())
        }
        return AnyView(DeferredSettingsView(makeViewModel: makeViewModel))
    }
}

/// Builds `SettingsView` (and its `@MainActor` ViewModel) inside a `@MainActor`
/// `body`, so `SettingsRouteProvider.destination(for:)` can stay `nonisolated`.
/// `internal` (not `Data/` — K4 does not apply) so the deferral is unit-testable.
struct DeferredSettingsView: View {
    let makeViewModel: @MainActor () -> SettingsViewModel

    var body: some View {
        SettingsView(viewModel: makeViewModel())
    }
}
