import Platform
import SwiftUI

/// A route that carries the code the Scanner screen just decoded, pushed onto
/// the Scanner tab's stack from the scan flow — or, from Task 7, resolved
/// from a `/scanner/result/:code` deep link.
///
/// Feature-private (ArchTests K9): no other feature references
/// `ScannerResultRoute`, so it stays out of `Platform.AppRoutes` and is
/// declared here instead. `code` is a plain `String`, which keeps the route
/// `Hashable` — required so `NavigationPath` can distinguish two pushes that
/// scanned different codes.
public struct ScannerResultRoute: AppRoute {
    public let code: String

    public init(code: String) {
        self.code = code
    }
}

/// The Scanner feature's contribution to `AppRouter` (Source Spec §4.3).
///
/// The `App` composition root registers one instance; the router calls
/// `canHandle` to match `AppRoutes.ScannerRoot` / `ScannerResultRoute` and
/// `destination(for:)` for the screen. The Scanner root's ViewModel is built
/// by an injected `@MainActor` closure; in production this is
/// `{ ScannerViewModel() }` which auto-resolves dependencies via
/// `Factory.Container`. `ResultViewModel` needs no such injection — it is
/// self-contained (Source Spec §5.4) — so it is built directly from the
/// route's `code`.
///
/// The `RouteProvider` requirements are `nonisolated`; `destination(for:)`
/// therefore hands back a tiny `Deferred…View` whose SwiftUI `body`
/// (`@MainActor` by construction) is where the `@MainActor` ViewModel and
/// screen are actually built. This keeps the conformance unisolated and
/// satisfies ArchTests K5's plain-`RouteProvider` conformance check (mirrors
/// `SettingsRouteProvider`).
public final class ScannerRouteProvider: RouteProvider {
    private let makeViewModel: @MainActor () -> ScannerViewModel

    public init(
        makeViewModel: @escaping @MainActor () -> ScannerViewModel
    ) {
        self.makeViewModel = makeViewModel
    }

    public func canHandle(_ route: any AppRoute) -> Bool {
        route is AppRoutes.ScannerRoot || route is ScannerResultRoute
    }

    /// Scanner's URL contract (Task 7, Source Spec §4.11): `/scanner` and
    /// `/scanner/result/:code`. Neither sets `requiresAuth` — the template
    /// ships no authentication feature, so gating a link here would deny the
    /// template's own demo link on a fresh clone (the flag's behaviour is
    /// covered elsewhere, by Task 5's fake guard and Task 9's injected one).
    ///
    /// **Convention:** each `build` closure's array is the parent-to-child
    /// stack, starting with this feature's tab-root route
    /// (`AppRoutes.ScannerRoot()`) as its first element — the router's
    /// `isTabRoot` de-duplication (Task 5) depends on that ordering to avoid
    /// pushing a duplicate root screen when landing on this tab.
    public var deepLinks: [DeepLinkRoute] {
        [
            DeepLinkRoute("/scanner") { _ in [AppRoutes.ScannerRoot()] },
            DeepLinkRoute("/scanner/result/:code") { params in
                // A pattern declaring `:code` cannot match a link missing that
                // segment, so `params["code"]` is always present here — `?? ""`
                // is defensive only, never a reachable fallback.
                [AppRoutes.ScannerRoot(), ScannerResultRoute(code: params["code"] ?? "")]
            },
        ]
    }

    public func destination(for route: any AppRoute) -> AnyView {
        if route is AppRoutes.ScannerRoot {
            return AnyView(DeferredScannerView(makeViewModel: makeViewModel))
        }
        if let resultRoute = route as? ScannerResultRoute {
            return AnyView(DeferredResultView(code: resultRoute.code))
        }
        return AnyView(EmptyView())
    }
}

/// Builds `ScannerView` (and its `@MainActor` ViewModel) inside a `@MainActor`
/// `body`, so `ScannerRouteProvider.destination(for:)` can stay `nonisolated`.
struct DeferredScannerView: View {
    let makeViewModel: @MainActor () -> ScannerViewModel

    var body: some View {
        ScannerView(viewModel: makeViewModel())
    }
}

/// Builds `ResultView` (and its `@MainActor` ViewModel) inside a `@MainActor`
/// `body`, mirroring `DeferredScannerView`. `ResultViewModel` is
/// self-contained — it owns no use cases — so it needs no injected factory
/// closure and is constructed directly from the route's `code`.
struct DeferredResultView: View {
    let code: String

    var body: some View {
        ResultView(viewModel: ResultViewModel(code: code))
    }
}
