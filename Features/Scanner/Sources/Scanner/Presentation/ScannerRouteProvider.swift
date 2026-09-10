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
