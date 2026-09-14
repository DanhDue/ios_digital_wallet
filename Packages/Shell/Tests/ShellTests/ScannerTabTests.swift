import Platform
import SwiftUI
import XCTest
@testable import Shell

private final class FakeScannerRouteProvider: RouteProvider {
    private(set) var destinationCallCount = 0
    private let label: String

    init(label: String) {
        self.label = label
    }

    func canHandle(_ route: any AppRoute) -> Bool {
        route is AppRoutes.ScannerRoot
    }

    func destination(for _: any AppRoute) -> AnyView {
        destinationCallCount += 1
        return AnyView(Text(label))
    }
}

/// Tests specifically verifying the Scanner tab integration in Shell.
/// Extracted from FeatureBlindRenderTests and ReTapTests so Shell tests
/// can be mode-aware and excluded in lean mode.
@MainActor
final class ScannerTabTests: XCTestCase {
    func testShellResolvesScannerTabContentThroughAFakeProvider() {
        let router = AppRouter(tabCount: 3, initialTab: 1)
        let provider = FakeScannerRouteProvider(label: "fake scanner")
        router.register(provider)

        _ = router.destination(for: AppRoutes.ScannerRoot())

        XCTAssertGreaterThan(provider.destinationCallCount, 0, "content came from the injected provider")
    }

    func testReTapLeavesScannerTabStackUntouched() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        router.navigate(to: AppRoutes.ScannerRoot(), inTab: 1)
        let bus = AppEventBus()
        let sut = ShellViewModel(config: ShellConfig(tabCount: 3, initialTab: 2), router: router, eventBus: bus)

        sut.dispatch(.selectTab(2))

        XCTAssertEqual(router.tabPaths[1].count, 1, "only the re-tapped tab is popped, scanner stack untouched")
    }
}
