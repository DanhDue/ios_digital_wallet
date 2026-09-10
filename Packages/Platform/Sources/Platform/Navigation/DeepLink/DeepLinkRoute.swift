import Foundation

/// One deep-linkable entry a feature declares through
/// ``RouteProvider/deepLinks`` (Source Spec §4.3): a pattern to match against
/// an incoming ``DeepLink``, whether reaching it requires authentication, and
/// how to turn the matched ``DeepLinkParams`` into the navigation stack to
/// push.
///
/// **`build` returns an array, not a single route.** The array is the
/// parent-to-child stack the router (Task 5) pushes in order, which is what
/// lets a deep link into a child screen also install its parent — so back
/// navigation from a deep-linked child lands inside the app instead of
/// outside it (blocker D6). Declaration order is preserved exactly: `build`
/// never reorders, deduplicates, or reverses its own result.
///
/// **`requiresAuth` is a plain `Bool`, not a type.** The feature only states
/// that reaching this route requires authentication; the host decides what
/// satisfies that requirement (Task 5). `Platform` never learns what "auth"
/// means — that split is invariant R1.
///
/// **`build` is `@MainActor`, not `@Sendable`.** This mirrors the existing
/// `makeViewModel: @MainActor () -> ViewModel` convention already used by
/// every shipped `RouteProvider` (see `SettingsRouteProvider`), and it is
/// exactly what lets `protocol AppRoute` stay `Sendable`-free — adding
/// `Sendable` there would ripple into every feature's route types for no
/// benefit, since the deep-link table is built and read exclusively on the
/// main actor. Do not "fix" this to `@Sendable`.
///
/// **Not `Sendable`.** For the same reason as above: a `Sendable`
/// `DeepLinkRoute` would force `AppRoute` to become `Sendable` too, since
/// `build`'s result type embeds it.
public struct DeepLinkRoute {
    /// The parsed pattern this route matches against a normalised
    /// ``DeepLink``.
    public let pattern: DeepLinkPattern

    /// Whether reaching this route requires the host to have satisfied some
    /// authentication requirement first. Defaults to `false`. `Platform`
    /// does not interpret this value — see the type-level doc comment.
    public let requiresAuth: Bool

    /// Builds the parent-to-child navigation stack for this route from the
    /// params a successful ``DeepLinkPattern/match(_:)`` produced. The
    /// result's order is the exact order routes should be pushed in.
    public let build: @MainActor (DeepLinkParams) -> [any AppRoute]

    /// Parses `pattern` and stores it alongside `requiresAuth` and `build`.
    ///
    /// Takes the pattern as a `String` and constructs the ``DeepLinkPattern``
    /// itself so feature authors write `DeepLinkRoute("/settings") { … }`
    /// rather than `DeepLinkRoute(DeepLinkPattern("/settings")) { … }`.
    public init(
        _ pattern: String,
        requiresAuth: Bool = false,
        build: @escaping @MainActor (DeepLinkParams) -> [any AppRoute]
    ) {
        self.pattern = DeepLinkPattern(pattern)
        self.requiresAuth = requiresAuth
        self.build = build
    }
}
