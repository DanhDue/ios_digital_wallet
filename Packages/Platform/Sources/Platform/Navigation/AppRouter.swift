import SwiftUI

/// Per-tab navigation state for the app shell.
///
/// Each tab owns an independent `NavigationPath` (`tabPaths[i]`), so switching
/// tabs preserves every tab's back stack — the iOS-native equivalent of
/// Android's `NestedNavigator`. A single shared path (the rejected v1 design) is
/// exactly what the per-tab isolation tests guard against.
///
/// `@MainActor`: every property is UI state, mutated from view callbacks.
@MainActor
public final class AppRouter: ObservableObject {
    /// Index of the visible tab.
    @Published public var selectedTab: Int

    /// One navigation stack per tab. `tabPaths.count` is the tab count and does
    /// not change after `init`.
    @Published public var tabPaths: [NavigationPath]

    private var providers: [any RouteProvider] = []

    /// - Parameters:
    ///   - tabCount: number of tabs; a negative value is treated as `0`.
    ///   - initialTab: initially-selected tab index.
    public init(tabCount: Int, initialTab: Int) {
        selectedTab = initialTab
        tabPaths = Array(repeating: NavigationPath(), count: max(0, tabCount))
    }

    /// Register a feature's ``RouteProvider``. Order matters: `destination(for:)`
    /// resolves against the first provider whose `canHandle` returns `true`.
    public func register(_ provider: any RouteProvider) {
        providers.append(provider)
    }

    /// Push `route` onto a tab's stack. `tab` defaults to `selectedTab`.
    ///
    /// An out-of-range `tab` is ignored (no trap) — this refines the spec's
    /// one-liner as the task's "guard gracefully" rule requires.
    public func navigate(to route: any AppRoute, inTab tab: Int? = nil) {
        let index = tab ?? selectedTab
        guard tabPaths.indices.contains(index) else { return }
        tabPaths[index].append(route)
    }

    /// Pop one level off a tab's stack. No-op on an empty stack or an
    /// out-of-range `tab`.
    public func pop(inTab tab: Int? = nil) {
        let index = tab ?? selectedTab
        guard tabPaths.indices.contains(index), !tabPaths[index].isEmpty else { return }
        tabPaths[index].removeLast()
    }

    /// Clear a tab's stack back to its root. No-op on an out-of-range `tab`.
    public func popToRoot(inTab tab: Int? = nil) {
        let index = tab ?? selectedTab
        guard tabPaths.indices.contains(index) else { return }
        tabPaths[index] = NavigationPath()
    }

    /// Select a tab. An out-of-range index is ignored so a bad value can never
    /// strand a later defaulted `navigate` / `pop` call.
    public func switchTab(_ index: Int) {
        guard tabPaths.indices.contains(index) else { return }
        selectedTab = index
    }

    /// Resolve `route` to a view via the first provider whose `canHandle`
    /// returns `true`. When none matches, the `@ViewBuilder` `if` yields no
    /// content — the SwiftUI equivalent of `EmptyView()` (SwiftFormat's
    /// `redundantEmptyView` rule canonicalises the explicit `else` branch away).
    @ViewBuilder
    public func destination(for route: any AppRoute) -> some View {
        if let provider = providers.first(where: { $0.canHandle(route) }) {
            provider.destination(for: route)
        }
    }
}
