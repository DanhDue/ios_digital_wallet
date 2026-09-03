import Combine
import Core
import Network
import Platform
import SwiftUI
import XCTest
@testable import iOSDigitalWallet

/// Tier A — composition-root behavior.
@MainActor
final class AppCompositionTests: XCTestCase {
    // MARK: Route-provider registration

    func testCompositionRegistersExactlyTwoRouteProviders() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.routeProviders.count, 2)

        let handlesSettings = sut.routeProviders.filter { $0.canHandle(AppRoutes.SettingsRoot()) }
        let handlesScanner = sut.routeProviders.filter { $0.canHandle(AppRoutes.ScannerRoot()) }
        XCTAssertEqual(handlesSettings.count, 1, "exactly one provider handles SettingsRoot")
        XCTAssertEqual(handlesScanner.count, 1, "exactly one provider handles ScannerRoot")
    }

    func testRouterResolvesBothSharedRoots() {
        let sut = AppComposition(eventBus: AppEventBus())

        // Resolves through the router the same way the shell resolves a tab root.
        _ = sut.router.destination(for: AppRoutes.SettingsRoot())
        _ = sut.router.destination(for: AppRoutes.ScannerRoot())
    }

    func testRouterIsBuiltWithThreeTabsAndSettingsSelected() {
        let sut = AppComposition(eventBus: AppEventBus())

        XCTAssertEqual(sut.router.tabPaths.count, 3)
        XCTAssertEqual(sut.router.selectedTab, 2)
    }

    // MARK: 401 → UserLoggedOut (exactly once)

    func test401FromTheComposedAPIClientPublishesExactlyOneUserLoggedOut() async {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(UserLoggedOut.self))

        let client = NetworkComposition.makeAPIClient(
            eventBus: bus,
            session: .stubbed401(),
            logger: SilentLogger()
        )

        do {
            let _: EmptyResponse = try await client.send(APIRequest(method: .get, path: "ping"))
            XCTFail("expected the 401 to throw")
        } catch {
            // NetworkError.unauthorized — expected.
        }

        XCTAssertEqual(recorder.count, 1, "exactly one UserLoggedOut per 401 response")
    }

    // MARK: Lifecycle mapping

    func testScenePhaseBackgroundPublishesBackgroundThenActivePublishesForeground() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.background)
        observer.handle(ScenePhase.active)

        XCTAssertEqual(recorder.values, [.background, .foreground])
    }

    func testRapidActiveBackgroundActivePublishesInThatExactOrder() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.active)
        observer.handle(ScenePhase.background)
        observer.handle(ScenePhase.active)

        XCTAssertEqual(recorder.values, [.foreground, .background, .foreground])
    }

    func testInactivePhaseMapsToInactive() {
        let bus = AppEventBus()
        let recorder = Recorder(bus.on(AppLifecycleChanged.self).map { LifecycleTag($0.state) })
        let observer = LifecycleObserver(eventBus: bus)

        observer.handle(ScenePhase.inactive)

        XCTAssertEqual(recorder.values, [.inactive])
    }
}
