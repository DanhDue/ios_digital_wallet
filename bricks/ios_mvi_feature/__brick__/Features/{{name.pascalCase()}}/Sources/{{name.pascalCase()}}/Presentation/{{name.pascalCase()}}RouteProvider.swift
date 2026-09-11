import Platform
import SwiftUI

/// Feature-local entry route for `{{name.pascalCase()}}`.
///
/// Kept inside the feature on purpose: a feature MAY declare its own private
/// `AppRoute` types (ArchTests K9). Promote it to
/// `Platform/Navigation/AppRoutes.swift` as `AppRoutes.{{name.pascalCase()}}Root`
/// only when another feature needs to navigate here.
/// See: Packages/Platform/Sources/Platform/Navigation/AppRoutes.swift
public struct {{name.pascalCase()}}Root: AppRoute {
    public init() {}
}

/// The `{{name.pascalCase()}}` feature's contribution to `AppRouter`
/// (Source Spec §4.3).
///
/// The `App` composition root registers one instance; the router calls
/// `canHandle` to match `{{name.pascalCase()}}Root` and `destination(for:)` for
/// the screen. The ViewModel is built by an injected `@MainActor` closure; in
/// production this is `{ {{name.pascalCase()}}ViewModel() }` which auto-resolves dependencies
/// via `Factory.Container`.
///
/// `destination(for:)` hands back a tiny `Deferred{{name.pascalCase()}}View`
/// whose SwiftUI `body` (`@MainActor` by construction) is where the `@MainActor`
/// ViewModel and `{{name.pascalCase()}}View` are actually built — keeping this
/// conformance `nonisolated` and satisfying ArchTests K5.
/// See: Features/Settings/Sources/Settings/Presentation/SettingsRouteProvider.swift
public final class {{name.pascalCase()}}RouteProvider: RouteProvider {
    private let makeViewModel: @MainActor () -> {{name.pascalCase()}}ViewModel

    public init(makeViewModel: @escaping @MainActor () -> {{name.pascalCase()}}ViewModel) {
        self.makeViewModel = makeViewModel
    }

    public func canHandle(_ route: any AppRoute) -> Bool {
        route is {{name.pascalCase()}}Root
    }

    /// This feature's URL contract: `/{{name.paramCase()}}`. Does not
    /// set `requiresAuth` — the template ships no authentication feature, so
    /// gating this link would deny it on a fresh clone (the flag's behaviour is
    /// covered elsewhere, by a fake guard in tests and a real one once the app
    /// has authentication).
    ///
    /// **Convention:** each `build` closure's array is the parent-to-child
    /// stack, starting with this feature's tab-root route
    /// (`{{name.pascalCase()}}Root()`) as its first element — the router's
    /// `isTabRoot` de-duplication depends on that ordering to avoid pushing a
    /// duplicate root screen when landing on this tab.
    /// See: Features/Scanner/Sources/Scanner/Presentation/ScannerRouteProvider.swift
    public var deepLinks: [DeepLinkRoute] {
        [DeepLinkRoute("/{{name.paramCase()}}") { _ in [{{name.pascalCase()}}Root()] }]
    }

    public func destination(for route: any AppRoute) -> AnyView {
        guard route is {{name.pascalCase()}}Root else {
            return AnyView(EmptyView())
        }
        return AnyView(Deferred{{name.pascalCase()}}View(makeViewModel: makeViewModel))
    }
}

/// Builds `{{name.pascalCase()}}View` (and its `@MainActor` ViewModel) inside a
/// `@MainActor` `body`, so `{{name.pascalCase()}}RouteProvider.destination(for:)`
/// can stay `nonisolated`. `internal` so the deferral is unit-testable.
struct Deferred{{name.pascalCase()}}View: View {
    let makeViewModel: @MainActor () -> {{name.pascalCase()}}ViewModel

    var body: some View {
        {{name.pascalCase()}}View(viewModel: makeViewModel())
    }
}
