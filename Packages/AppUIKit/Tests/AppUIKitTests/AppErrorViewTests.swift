import Core
import SwiftUI
import XCTest
@testable import AppUIKit

@MainActor
final class AppErrorViewTests: XCTestCase {
    func testNilRetryClosureHidesTheRetryAffordance() {
        let view = AppErrorView(message: "Boom", retry: nil)
        XCTAssertFalse(view.showsRetry)
    }

    func testDefaultInitHasNoRetry() {
        let view = AppErrorView(message: "Boom")
        XCTAssertFalse(view.showsRetry)
    }

    func testNonNilRetryClosureShowsTheRetryAffordance() {
        let view = AppErrorView(message: "Boom") {}
        XCTAssertTrue(view.showsRetry)
    }

    func testAppErrorConvenienceInitUsesTheErrorMessage() {
        let error = AppError(code: "net.timeout", message: "The request timed out")
        let view = AppErrorView(error)
        XCTAssertFalse(view.showsRetry)
        assertRenders(view)
    }

    func testAppErrorConvenienceInitKeepsRetry() {
        let error = AppError(code: "net.timeout", message: "The request timed out")
        let view = AppErrorView(error) {}
        XCTAssertTrue(view.showsRetry)
    }

    func testRendersWithAndWithoutRetry() {
        assertRenders(AppErrorView(message: "Boom"))
        assertRenders(AppErrorView(message: "Boom") {})
    }

    func testRetryClosureIsInvokedWhenCalled() {
        var count = 0
        let view = AppErrorView(message: "Boom") { count += 1 }
        view.performRetry()
        XCTAssertEqual(count, 1)
    }
}
