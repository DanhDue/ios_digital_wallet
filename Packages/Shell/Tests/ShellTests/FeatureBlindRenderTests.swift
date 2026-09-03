import Foundation
import Platform
import SwiftUI
import XCTest
@testable import Shell

#if canImport(UIKit)
    import UIKit
#endif

/// The shell resolves tab content only through `AppRouter.destination(for:)` and
/// no source file pulls in a feature module (BDD: feature-blindness, structural).
@MainActor
final class FeatureBlindRenderTests: XCTestCase {
    func testShellResolvesSettingsTabContentThroughAFakeProvider() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        let provider = FakeRouteProvider(label: "fake settings")
        router.register(provider)

        _ = router.destination(for: AppRoutes.SettingsRoot())

        XCTAssertGreaterThan(provider.destinationCallCount, 0, "content came from the injected provider")
    }

    #if canImport(UIKit)
        func testHostingShellViewWithAFakeProviderDoesNotCrashAndResolvesTabTwo() {
            let router = AppRouter(tabCount: 3, initialTab: 2)
            let provider = FakeRouteProvider(label: "fake settings")
            router.register(provider)
            let sut = ShellViewModel(
                config: ShellConfig(tabCount: 3, initialTab: 2),
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
                "tab 2 root resolved via the fake provider, not a Feature import"
            )
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
