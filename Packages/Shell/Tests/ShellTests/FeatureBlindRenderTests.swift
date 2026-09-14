import Foundation
import Platform
import SwiftUI
import XCTest
@testable import Shell

#if canImport(UIKit)
    import UIKit
#endif

/// A route with **no entry in `AppRoutes`** — the shape of every feature-private
/// child screen a deep link will eventually target. Declared here, in the test
/// target, and never in a Feature module: Shell's tests must stay feature-blind
/// exactly like Shell's sources (ArchTests K6).
private struct UnregisteredFeaturePrivateRoute: AppRoute {
    let id: Int
}

/// Handles only `UnregisteredFeaturePrivateRoute` — kept separate from
/// `FakeRouteProvider` (which only recognizes the two `AppRoutes` values) so a
/// passing test proves resolution came from the erased destination, not from
/// an accidental match against the shared-route fake.
private final class UnregisteredRouteProvider: RouteProvider {
    private(set) var destinationCallCount = 0
    private(set) var lastRoute: (any AppRoute)?

    func canHandle(_ route: any AppRoute) -> Bool {
        route is UnregisteredFeaturePrivateRoute
    }

    func destination(for route: any AppRoute) -> AnyView {
        destinationCallCount += 1
        lastRoute = route
        return AnyView(Text("unregistered"))
    }
}

/// The shell resolves tab content only through `AppRouter.destination(for:)` and
/// no source file pulls in a feature module (BDD: feature-blindness, structural).
@MainActor
final class FeatureBlindRenderTests: XCTestCase {
    func testShellResolvesSettingsTabContentThroughAFakeProvider() {
        let config = ShellConfig()
        let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
        let provider = FakeRouteProvider(label: "fake settings")
        router.register(provider)

        _ = router.destination(for: AppRoutes.SettingsRoot())

        XCTAssertGreaterThan(provider.destinationCallCount, 0, "content came from the injected provider")
    }

    #if canImport(UIKit)
        func testHostingShellViewWithAFakeProviderDoesNotCrashAndResolvesTabTwo() {
            let config = ShellConfig()
            let router = AppRouter(tabCount: config.tabCount, initialTab: config.initialTab)
            let provider = FakeRouteProvider(label: "fake settings")
            router.register(provider)
            let sut = ShellViewModel(
                config: config,
                router: router,
                eventBus: AppEventBus()
            )

            let host = UIHostingController(rootView: ShellView(viewModel: sut, router: router))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))

            XCTAssertNotNil(host.view)
            XCTAssertGreaterThan(
                provider.destinationCallCount,
                0,
                "settings root resolved via the fake provider, not a Feature import"
            )
        }

        func testPushingARouteWithNoAppRoutesEntryRendersItsViewInsteadOfBlank() {
            // Regression guard for blocker D3: before the AnyAppRoute erasure,
            // ShellView named only `AppRoutes.SettingsRoot` / `.ScannerRoot` in
            // its `.navigationDestination`s, so any other route — every
            // feature-private child screen — rendered nothing. Pushing this
            // unregistered type into tab 0 (which never had a per-type
            // destination for it, before or after) and observing the fake
            // provider fire is the "demonstrated by a test" proof the DoD asks
            // for.
            let config = ShellConfig()
            let router = AppRouter(tabCount: config.tabCount, initialTab: 0)
            let unregisteredProvider = UnregisteredRouteProvider()
            router.register(unregisteredProvider)
            router.navigate(to: UnregisteredFeaturePrivateRoute(id: 1), inTab: 0)

            let sut = ShellViewModel(
                config: ShellConfig(tabCount: config.tabCount, initialTab: 0),
                router: router,
                eventBus: AppEventBus()
            )

            let host = UIHostingController(rootView: ShellView(viewModel: sut, router: router))
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            XCTAssertNotNil(host.view)
            XCTAssertGreaterThan(
                unregisteredProvider.destinationCallCount,
                0,
                "a route absent from AppRoutes must resolve through the single erased destination, not render blank"
            )
            XCTAssertTrue(unregisteredProvider.lastRoute is UnregisteredFeaturePrivateRoute)
        }
    #endif

    func testNoShellSourceFileImportsAFeatureModule() throws {
        let files = try shellSourceFiles()
        XCTAssertFalse(files.isEmpty, "found no Swift sources under Packages/Shell/Sources")

        let importFeature = try NSRegularExpression(pattern: #"(?m)^\s*(@testable\s+)?import\s+\S*Feature\b"#)

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            XCTAssertNil(
                importFeature.firstMatch(in: text, range: range),
                "\(file.lastPathComponent) imports a Feature module — Shell must stay feature-blind"
            )

            // The literal grep the task mandates: no line carries both an
            // import statement and the token `Feature`.
            for line in text.split(separator: "\n") where line.contains("import ") {
                XCTAssertFalse(
                    line.contains("Feature"),
                    "\(file.lastPathComponent): `\(line)` couples an import to a Feature"
                )
            }
        }
    }
}
