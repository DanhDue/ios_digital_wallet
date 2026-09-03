import SwiftUI
import XCTest
@testable import AppUIKit

@MainActor
final class AppEmptyStateViewTests: XCTestCase {
    func testRendersAVeryLongTitleWithoutCrashing() {
        let longTitle = String(repeating: "Nothing to see here. ", count: 200)
        assertRenders(AppEmptyStateView(title: longTitle))
    }

    func testShowsMessageOnlyWhenProvidedAndNonEmpty() {
        XCTAssertFalse(AppEmptyStateView(title: "T").showsMessage)
        XCTAssertFalse(AppEmptyStateView(title: "T", message: "").showsMessage)
        XCTAssertTrue(AppEmptyStateView(title: "T", message: "More info").showsMessage)
    }

    func testRendersWithAndWithoutMessage() {
        assertRenders(AppEmptyStateView(title: "Empty"))
        assertRenders(AppEmptyStateView(title: "Empty", message: "Try again later."))
        assertRenders(AppEmptyStateView(title: "Empty", message: "x", systemImage: "magnifyingglass"))
    }

    func testRendersWithEmptyTitle() {
        assertRenders(AppEmptyStateView(title: ""))
    }
}
