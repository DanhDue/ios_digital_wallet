/// A destination value that can be pushed onto a tab's navigation stack.
///
/// `Hashable` so it can be appended to `SwiftUI.NavigationPath` and matched by
/// `.navigationDestination(for:)`. Cross-feature route values live in
/// ``AppRoutes``; each feature also declares its own private routes.
public protocol AppRoute: Hashable {}
