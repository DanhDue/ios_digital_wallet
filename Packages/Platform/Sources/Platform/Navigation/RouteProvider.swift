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
}
