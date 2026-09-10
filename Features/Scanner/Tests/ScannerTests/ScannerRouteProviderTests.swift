import Platform
import SwiftUI
import XCTest
@testable import Scanner

@MainActor
final class ScannerRouteProviderTests: XCTestCase {
    private func makeProvider(onBuild: @escaping () -> Void = {}) -> ScannerRouteProvider {
        ScannerRouteProvider {
            onBuild()
            return ScannerViewModel(repository: SpyScannerRepository())
        }
    }

    func testCanHandleIsTrueForScannerRootOnly() {
        let provider = makeProvider()

        XCTAssertTrue(provider.canHandle(AppRoutes.ScannerRoot()))
        XCTAssertFalse(provider.canHandle(AppRoutes.SettingsRoot()))
    }

    func testDestinationForScannerRootReturnsAViewAndDefersViewModelConstruction() {
        var built = 0
        let provider = makeProvider { built += 1 }

        let view = provider.destination(for: AppRoutes.ScannerRoot())

        XCTAssertTrue(String(describing: type(of: view)).contains("AnyView"))
        XCTAssertEqual(built, 0, "the ViewModel is built lazily, inside the SwiftUI body — not at resolve time")
    }

    func testDeferredScannerViewBodyBuildsTheViewModelExactlyOnce() {
        var built = 0
        let deferred = DeferredScannerView {
            built += 1
            return ScannerViewModel(repository: SpyScannerRepository())
        }

        _ = deferred.body

        XCTAssertEqual(built, 1)
    }

    func testDestinationForAForeignRouteDoesNotBuildAViewModel() {
        var built = 0
        let provider = makeProvider { built += 1 }

        _ = provider.destination(for: AppRoutes.SettingsRoot())

        XCTAssertEqual(built, 0)
    }

    func testRegistersAndResolvesThroughAppRouter() {
        let router = AppRouter(tabCount: 3, initialTab: 1)
        router.register(makeProvider())

        let resolved = router.destination(for: AppRoutes.ScannerRoot())
        XCTAssertNotNil(resolved)
    }

    func testContainerRegistrationBuildsAProviderThatHandlesScannerRootOnly() {
        let provider = ScannerRouteProvider { ScannerViewModel() }

        XCTAssertTrue(provider.canHandle(AppRoutes.ScannerRoot()))
        XCTAssertFalse(provider.canHandle(AppRoutes.SettingsRoot()))
        _ = provider.destination(for: AppRoutes.ScannerRoot())
    }

    // MARK: - ScannerResultRoute (Task 6) — route identity

    /// Equivalence Partitioning over the `code` payload: empty, a single
    /// character, a long string, unicode, a code containing `/` (Task 2 can
    /// hand the router a `%2F`-decoded code shaped like this), and a code
    /// that looks like a URL.
    private static let codePartitions = [
        "",
        "A",
        String(repeating: "x", count: 2000),
        "阿β🎉こんにちは",
        "abc/def/ghi",
        "https://example.com/product?id=42&ref=/promo",
    ]

    func testScannerResultRouteWithSameCodeAreEqualAndHashEqually() {
        let first = ScannerResultRoute(code: "ABC123")
        let second = ScannerResultRoute(code: "ABC123")

        XCTAssertEqual(first, second)
        XCTAssertEqual(Set([first, second]).count, 1, "equal routes must collapse into one Set entry")
    }

    func testScannerResultRouteWithDifferentCodesAreNotEqual() {
        let first = ScannerResultRoute(code: "ABC123")
        let second = ScannerResultRoute(code: "XYZ789")

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(Set([first, second]).count, 2)
    }

    func testScannerResultRouteNeverEqualsScannerRootWhenErased() {
        let result = AnyAppRoute(ScannerResultRoute(code: "ABC123"))
        let root = AnyAppRoute(AppRoutes.ScannerRoot())

        XCTAssertNotEqual(result, root)
    }

    // MARK: - ScannerResultRoute (Task 6) — provider resolution

    func testCanHandleIsTrueForScannerResultRouteAcrossEveryCodePartition() {
        let provider = makeProvider()

        for code in Self.codePartitions {
            XCTAssertTrue(
                provider.canHandle(ScannerResultRoute(code: code)),
                "canHandle must be true for code partition \(code.prefix(24))"
            )
        }
    }

    func testCanHandleIsFalseForAnUnrelatedRouteEvenAfterLearningScannerResultRoute() {
        let provider = makeProvider()

        XCTAssertFalse(provider.canHandle(AppRoutes.SettingsRoot()))
    }

    func testDestinationForScannerResultRouteReturnsTheResultViewNotEmptyView() {
        let provider = makeProvider()

        let view = provider.destination(for: ScannerResultRoute(code: "ABC123"))

        XCTAssertTrue(String(describing: view).contains("DeferredResultView"))
        XCTAssertFalse(String(describing: view).contains("EmptyView"))
    }

    func testDestinationForScannerResultRouteResolvesForEveryCodePartition() {
        let provider = makeProvider()

        for code in Self.codePartitions {
            let view = provider.destination(for: ScannerResultRoute(code: code))
            XCTAssertFalse(
                String(describing: view).contains("EmptyView"),
                "destination must not be empty for code partition \(code.prefix(24))"
            )
        }
    }

    func testDestinationForAnUnrelatedRouteReturnsEmptyView() {
        let provider = makeProvider()

        let view = provider.destination(for: AppRoutes.SettingsRoot())

        XCTAssertTrue(String(describing: view).contains("EmptyView"))
    }

    func testRegistersAndResolvesScannerResultRouteThroughAppRouter() {
        let router = AppRouter(tabCount: 3, initialTab: 1)
        router.register(makeProvider())

        let resolved = router.destination(for: ScannerResultRoute(code: "ABC123"))
        XCTAssertNotNil(resolved)
    }

    /// Definition of Done: `router.navigate(to: ScannerResultRoute(code:
    /// "ABC123"))` renders the result screen — impossible before Task 1, since
    /// `ShellView` had no destination for a route it didn't statically name.
    /// `AnyAppRoute` erasure (Task 1) is what lets `AppRouter.destination(for:)`
    /// resolve any pushed route, `ScannerResultRoute` included, through the
    /// single registered provider.
    func testNavigatingToScannerResultRoutePushesItAndResolvesToTheResultView() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        router.register(makeProvider())

        router.navigate(to: ScannerResultRoute(code: "ABC123"))

        XCTAssertEqual(router.tabPaths[0].count, 1, "the route must be pushed onto the tab's stack")

        let resolved = router.destination(for: ScannerResultRoute(code: "ABC123"))
        XCTAssertTrue(String(describing: resolved).contains("DeferredResultView"))
    }
}
