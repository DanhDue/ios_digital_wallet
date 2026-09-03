import SwiftUI
import XCTest
@testable import AppUIKit

@MainActor
final class AppButtonTests: XCTestCase {
    // MARK: tap-suppression logic (pure, no UI hit-testing)

    func testEnabledIdleButtonAcceptsTaps() {
        let button = AppButton("Go", enabled: true, loading: false) {}
        XCTAssertTrue(button.acceptsTap)
    }

    func testLoadingButtonDoesNotAcceptTaps() {
        let button = AppButton("Go", loading: true) {}
        XCTAssertFalse(button.acceptsTap)
    }

    func testDisabledButtonDoesNotAcceptTaps() {
        let button = AppButton("Go", enabled: false) {}
        XCTAssertFalse(button.acceptsTap)
    }

    func testDisabledAndLoadingButtonDoesNotAcceptTaps() {
        let button = AppButton("Go", enabled: false, loading: true) {}
        XCTAssertFalse(button.acceptsTap)
    }

    // MARK: action closure

    func testEnabledTapInvokesActionExactlyOnce() {
        var count = 0
        let button = AppButton("Go") { count += 1 }
        button.handleTap()
        XCTAssertEqual(count, 1)
    }

    func testLoadingTapIsANoOp() {
        var count = 0
        let button = AppButton("Go", loading: true) { count += 1 }
        button.handleTap()
        button.handleTap()
        XCTAssertEqual(count, 0)
    }

    func testDisabledTapIsANoOp() {
        var count = 0
        let button = AppButton("Go", enabled: false) { count += 1 }
        button.handleTap()
        XCTAssertEqual(count, 0)
    }

    func testRepeatedEnabledTapsInvokeActionOncePerTap() {
        var count = 0
        let button = AppButton("Go") { count += 1 }
        button.handleTap()
        button.handleTap()
        button.handleTap()
        XCTAssertEqual(count, 3)
    }

    // MARK: render smoke — every style / state builds without crashing

    func testAllStylesAndStatesRender() {
        for style in [AppButton.Style.primary, .secondary, .destructive] {
            assertRenders(AppButton("Label", style: style) {})
            assertRenders(AppButton("Label", style: style, enabled: false) {})
            assertRenders(AppButton("Label", style: style, loading: true) {})
        }
    }
}
