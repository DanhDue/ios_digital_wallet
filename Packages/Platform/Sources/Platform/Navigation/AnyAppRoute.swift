/// A type-erased ``AppRoute`` for storage in `SwiftUI.NavigationPath`.
///
/// `NavigationPath.append` keys `.navigationDestination(for:)` matching to the
/// *concrete* static type of the appended value, so pushing bare route values
/// forces `ShellView` to name one `.navigationDestination` per route type —
/// exactly the blank-screen failure recorded as blocker **D3** in the Source
/// Spec (§1.3): any route `ShellView` doesn't name renders nothing.
/// `AnyAppRoute` erases that boundary. `AppRouter.navigate(to:inTab:)` boxes
/// every route before it reaches `NavigationPath`, so `ShellView` collapses to
/// a single `.navigationDestination(for: AnyAppRoute.self)` that serves every
/// route — shared or feature-private, present or future — without ever
/// naming a concrete type.
///
/// `AppRoute` itself stays a bare `Hashable` marker (see `AppRoute.swift`);
/// only the value stored in `NavigationPath` is boxed here. Features keep
/// declaring plain structs and never see this type. `AppRouter.destination(
/// for:)` is untouched — it still takes `any AppRoute` — so callers unwrap
/// with `.wrapped` at the call site (`ShellView.tabStack`).
///
/// **Implementation variant (compile-risk decision, recorded per the task
/// brief):** `wrapped` is stored directly as `any AppRoute`, and
/// `AnyHashable(wrapped)` — opening the existential implicitly — compiles
/// cleanly under Swift 6 strict concurrency, so that is the variant used
/// here; the `base: AnyHashable`-storage fallback the brief documents was not
/// needed.
///
/// Equality and hashing delegate entirely to `AnyHashable(wrapped)`, which
/// compares both the underlying concrete type and the stored value. Two
/// different route types with identical stored properties therefore compare
/// **unequal** — required so `NavigationPath` never conflates distinct routes
/// during deduplication or back navigation.
public struct AnyAppRoute: Hashable {
    /// The original route, recovered exactly as it was boxed.
    public let wrapped: any AppRoute

    public init(_ route: any AppRoute) {
        wrapped = route
    }

    public static func == (lhs: AnyAppRoute, rhs: AnyAppRoute) -> Bool {
        AnyHashable(lhs.wrapped) == AnyHashable(rhs.wrapped)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(wrapped))
    }
}
