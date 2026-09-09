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
}
