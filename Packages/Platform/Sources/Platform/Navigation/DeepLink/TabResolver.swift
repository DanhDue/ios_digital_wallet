import Foundation

/// The host's tab-placement seam (Source Spec §4.5): answers "which tab, and
/// is this route that tab's own root" for the first route of a matched (or
/// redirect) stack. `Platform` never learns the shell's tab layout — the
/// resolver answers a placement question about one opaque route (invariant
/// R1).
///
/// **Optional, and its answer is optional.** `nil` at `DeepLinkRouter.init`,
/// or a `nil` return from `placement(for:)`, both mean "no opinion" — the
/// router falls back to `AppRouter.selectedTab`.
@MainActor
public protocol TabResolver {
    /// - Parameter route: the first element of the stack about to be
    ///   navigated to, i.e. what would become that tab's new root.
    /// - Returns: `nil` when this resolver has no opinion about `route`.
    func placement(for route: any AppRoute) -> TabPlacement?
}

/// Where a route lands.
public struct TabPlacement: Equatable, Sendable {
    /// The tab index to select. An index outside `AppRouter.tabPaths`'s
    /// bounds is treated by `DeepLinkRouter` the same as "no opinion": every
    /// `AppRouter` mutator silently no-ops on a bad index, so the router
    /// falls back to `AppRouter.selectedTab` and logs the bad placement
    /// rather than reporting a false `.opened` that moved nothing.
    public let tab: Int

    /// `true` when `route` is that tab's own root screen (e.g.
    /// `AppRoutes.SettingsRoot`). `ShellView` already renders every tab's
    /// root; without this flag `DeepLinkRouter` would `popToRoot` (already
    /// showing that root) and then push the identical root again,
    /// duplicating the screen.
    public let isTabRoot: Bool

    public init(tab: Int, isTabRoot: Bool) {
        self.tab = tab
        self.isTabRoot = isTabRoot
    }
}
