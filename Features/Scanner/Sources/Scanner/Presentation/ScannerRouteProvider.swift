import Platform
import SwiftUI

/// The Scanner feature's contribution to `AppRouter` (Source Spec §4.3).
///
/// The `App` composition root registers one instance; the router calls
/// `canHandle` to match `AppRoutes.ScannerRoot` and `destination(for:)` for the
/// screen. The ViewModel is built by an injected `@MainActor` closure so the
/// provider owns no dependencies of its own — see
/// `ScannerModule.makeRouteProvider`.
///
/// The `RouteProvider` requirements are `nonisolated`; `destination(for:)`
/// therefore hands back a tiny `DeferredScannerView` whose SwiftUI `body`
/// (`@MainActor` by construction) is where the `@MainActor` ViewModel and
/// `ScannerView` are actually built. This keeps the conformance unisolated and
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
        route is AppRoutes.ScannerRoot
    }

    public func destination(for route: any AppRoute) -> AnyView {
        guard route is AppRoutes.ScannerRoot else {
            return AnyView(EmptyView())
        }
        return AnyView(DeferredScannerView(makeViewModel: makeViewModel))
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
