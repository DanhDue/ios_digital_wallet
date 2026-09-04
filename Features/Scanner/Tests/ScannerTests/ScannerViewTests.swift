import SwiftUI
import XCTest
@testable import Scanner

#if canImport(UIKit)
    import UIKit
#endif

@MainActor
final class ScannerViewTests: XCTestCase {
    func testViewBuildsFromTheModuleFactory() {
        let view = ScannerView(viewModel: ScannerModule.makeViewModel())
        XCTAssertNotNil(view.body)
    }

    #if canImport(UIKit)
        func testHostingScannerViewDoesNotCrash() {
            let host = UIHostingController(
                rootView: NavigationStack { ScannerView(viewModel: ScannerModule.makeViewModel()) }
            )
            host.loadViewIfNeeded()
            host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))

            XCTAssertNotNil(host.view)
        }
    #endif
}
