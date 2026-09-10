import SwiftUI
import XCTest
@testable import Scanner

#if canImport(UIKit)
    import UIKit
#endif

/// `ResultView` is thin — it renders `viewModel.viewState` and dispatches
/// `.onAppear`; every value assertion belongs on `ResultViewModelTests`
/// (mirrors `ScannerView` / `ScannerViewModel`'s split). These tests only
/// prove the view builds and hosts without crashing for representative
/// codes, matching `ScannerViewTests`'s convention.
@MainActor
final class ResultViewTests: XCTestCase {
    func testViewBuildsFromTheModuleFactory() {
        let view = ResultView(viewModel: ResultViewModel(code: "ABC123"))
        XCTAssertNotNil(view.body)
    }

    func testViewBuildsForTheEmptyStringCodePartition() {
        let view = ResultView(viewModel: ResultViewModel(code: ""))
        XCTAssertNotNil(view.body)
    }

    #if canImport(UIKit)
        func testHostingResultViewDoesNotCrashForAUrlShapedCode() {
            let host = UIHostingController(
                rootView: NavigationStack {
                    ResultView(viewModel: ResultViewModel(code: "https://example.com/product?id=42&ref=/promo"))
                }
            )
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))

            XCTAssertNotNil(host.view)
        }
    #endif
}
