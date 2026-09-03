import SwiftUI
import XCTest
@testable import AppUIKit

@MainActor
final class AppLoadingViewTests: XCTestCase {
    func testDefaultAccessibilityLabelIsLoading() {
        let view = AppLoadingView()
        XCTAssertEqual(view.accessibilityLabelText, "Loading")
    }

    func testDefaultLabelConstantIsLoading() {
        XCTAssertEqual(AppLoadingView.defaultLabel, "Loading")
    }

    func testCustomLabelIsRespected() {
        let view = AppLoadingView(label: "Fetching transactions")
        XCTAssertEqual(view.accessibilityLabelText, "Fetching transactions")
    }

    func testRenders() {
        assertRenders(AppLoadingView())
        assertRenders(AppLoadingView(label: "Working"))
    }
}
