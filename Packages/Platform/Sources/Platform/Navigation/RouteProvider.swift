import SwiftUI

/// One feature's contribution to the router.
///
/// The composition root (`App`) registers every feature's provider on the shared
/// ``AppRouter``; the router asks each in turn whether it `canHandle` a route
/// and, if so, for its `destination` view. This keeps ``AppRouter`` blind to
/// concrete feature types.
public protocol RouteProvider {
    /// `true` iff this provider can build a view for `route`.
    func canHandle(_ route: any AppRoute) -> Bool

    /// The view for `route`. Only invoked when `canHandle(route)` is `true`.
    @ViewBuilder
    func destination(for route: any AppRoute) -> AnyView

    /// The deep links this feature contributes to the router (Task 5's
    /// `DeepLinkRouter` reads this to build its resolution table). Defaults
    /// to `[]` — see the extension below — so every `RouteProvider` written
    /// before this requirement existed keeps compiling unchanged; a feature
    /// opts in by overriding this property.
    ///
    /// `@MainActor` on an otherwise-unisolated protocol is safe here: the
    /// deep-link table is built and read exclusively on the main actor by
    /// Task 5's router, which is itself `@MainActor`. `AppRouter` stores
    /// `[any RouteProvider]` and calls `canHandle`/`destination` from
    /// nonisolated context but never touches `deepLinks`.
    @MainActor
    var deepLinks: [DeepLinkRoute] { get }
}

public extension RouteProvider {
    /// The default: a provider that declares no deep links. Enforcing that
    /// cross-feature routes actually declare a pattern is ArchTests K10.2's
    /// job (a later task), not this compiler-level default.
    @MainActor
    var deepLinks: [DeepLinkRoute] {
        []
    }
}
