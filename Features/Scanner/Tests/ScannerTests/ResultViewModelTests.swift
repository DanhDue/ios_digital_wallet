import Combine
import XCTest
@testable import Scanner

/// ### BDD Scenarios (Task 6 — Scanner Result Subfeature)
///
/// `ResultViewModel` is self-contained: it owns no use case and does no I/O.
/// The code to display arrives already resolved — from
/// `ScannerResultRoute.code` — at construction time, so `.onAppear` only
/// needs to flip `viewState` from `.loading` to `.content`; there is nothing
/// to fetch and nothing that can fail.
///
/// See: Features/Scanner/Tests/ScannerTests/ScannerViewModelTests.swift
@MainActor
final class ResultViewModelTests: XCTestCase {
    /// Equivalence Partitioning over the `code` payload: empty, a single
    /// character, a long string, unicode, a code containing `/`, and a code
    /// that looks like a URL.
    private static let codePartitions = [
        "",
        "A",
        String(repeating: "x", count: 2000),
        "阿β🎉こんにちは",
        "abc/def/ghi",
        "https://example.com/product?id=42&ref=/promo",
    ]

    func testInitialViewStateIsLoadingBeforeOnAppear() {
        let sut = ResultViewModel(code: "ABC123")

        XCTAssertEqual(sut.viewState.tag, "loading")
    }

    func testInitialStateCodeMatchesTheCodeItWasConstructedWith() {
        let sut = ResultViewModel(code: "ABC123")

        XCTAssertEqual(sut.uiState.code, "ABC123")
    }

    func testOnAppearTransitionsViewStateToContent() {
        let sut = ResultViewModel(code: "ABC123")

        sut.dispatch(.onAppear)

        XCTAssertEqual(sut.viewState.tag, "content")
    }

    func testOnAppearDoesNotMutateTheCode() {
        let sut = ResultViewModel(code: "ABC123")

        sut.dispatch(.onAppear)

        XCTAssertEqual(sut.uiState.code, "ABC123")
    }

    func testStateCodeSurvivesUnchangedAcrossEveryPayloadPartition() {
        for code in Self.codePartitions {
            let sut = ResultViewModel(code: code)

            XCTAssertEqual(sut.uiState.code, code, "code must be readable before onAppear")

            sut.dispatch(.onAppear)

            XCTAssertEqual(sut.uiState.code, code, "code must be unchanged after onAppear")
            XCTAssertEqual(sut.viewState.tag, "content")
        }
    }

    func testTwoInstancesConstructedWithDifferentCodesDoNotShareState() {
        let first = ResultViewModel(code: "ABC123")
        let second = ResultViewModel(code: "XYZ789")

        XCTAssertEqual(first.uiState.code, "ABC123")
        XCTAssertEqual(second.uiState.code, "XYZ789")
    }
}
