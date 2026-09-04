import XCTest
@testable import Core

/// Behavioural coverage for the `TokenRefresher` DIP seam: the `NoTokenRefresher`
/// default, the `TokenRefreshResult` value type, and the `TokenRefreshFailure`
/// equivalence partitions.
final class TokenRefresherTests: XCTestCase {
    // MARK: NoTokenRefresher — always force-logout, never spin

    func testNoTokenRefresherFailsWithInvalidGrantForANormalToken() async {
        let result = await NoTokenRefresher().refresh(refreshToken: "a-real-looking-token")
        guard case .failure(.invalidGrant) = result else {
            return XCTFail("expected .failure(.invalidGrant), got \(result)")
        }
    }

    func testNoTokenRefresherFailsWithInvalidGrantForAnEmptyToken() async {
        let result = await NoTokenRefresher().refresh(refreshToken: "")
        guard case .failure(.invalidGrant) = result else {
            return XCTFail("expected .failure(.invalidGrant), got \(result)")
        }
    }

    func testNoTokenRefresherFailsWithInvalidGrantForAWhitespaceOnlyToken() async {
        let result = await NoTokenRefresher().refresh(refreshToken: "   \t\n")
        guard case .failure(.invalidGrant) = result else {
            return XCTFail("expected .failure(.invalidGrant), got \(result)")
        }
    }

    func testNoTokenRefresherNeverReturnsTransient() async {
        let result = await NoTokenRefresher().refresh(refreshToken: "x")
        if case .failure(.transient) = result {
            XCTFail("NoTokenRefresher must force logout, not spin on .transient")
        }
    }

    func testNoTokenRefresherNeverReturnsSuccess() async {
        let result = await NoTokenRefresher().refresh(refreshToken: "x")
        if case .success = result {
            XCTFail("an unwired app must not believe it holds a fresh token")
        }
    }

    func testNoTokenRefresherIsUsableThroughTheExistentialProtocol() async {
        let refresher: any TokenRefresher = NoTokenRefresher()
        let result = await refresher.refresh(refreshToken: "x")
        guard case .failure(.invalidGrant) = result else {
            return XCTFail("expected .failure(.invalidGrant), got \(result)")
        }
    }

    // MARK: TokenRefreshResult — construct & read back each case

    func testSuccessCarriesAccessTokenAndRotatedRefreshToken() {
        let result = TokenRefreshResult.success(accessToken: "new-access", refreshToken: "new-refresh")
        guard case let .success(accessToken, refreshToken) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(accessToken, "new-access")
        XCTAssertEqual(refreshToken, "new-refresh")
    }

    func testSuccessAllowsANilRefreshTokenMeaningKeepTheCurrentOne() {
        let result = TokenRefreshResult.success(accessToken: "new-access", refreshToken: nil)
        guard case let .success(accessToken, refreshToken) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(accessToken, "new-access")
        XCTAssertNil(refreshToken)
    }

    func testSuccessAcceptsAnEmptyRotatedRefreshTokenDistinctFromNil() {
        let result = TokenRefreshResult.success(accessToken: "a", refreshToken: "")
        guard case let .success(_, refreshToken) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(refreshToken, "")
        XCTAssertNotNil(refreshToken)
    }

    func testFailureCarriesItsUnderlyingReason() {
        let result = TokenRefreshResult.failure(.transient)
        guard case let .failure(failure) = result else {
            return XCTFail("expected .failure, got \(result)")
        }
        XCTAssertEqual(failure, .transient)
    }

    // MARK: TokenRefreshFailure — Equatable equivalence partitions

    func testInvalidGrantAndTransientAreDistinct() {
        XCTAssertNotEqual(TokenRefreshFailure.invalidGrant, .transient)
    }

    func testEachFailureEqualsItself() {
        XCTAssertEqual(TokenRefreshFailure.invalidGrant, .invalidGrant)
        XCTAssertEqual(TokenRefreshFailure.transient, .transient)
    }

    // MARK: async — callable off the main actor, no @MainActor inference

    func testRefreshIsCallableOffTheMainActor() async {
        let value = await Task.detached {
            await NoTokenRefresher().refresh(refreshToken: "off-main")
        }.value
        guard case .failure(.invalidGrant) = value else {
            return XCTFail("expected .failure(.invalidGrant), got \(value)")
        }
    }

    func testATestDoubleRefresherCanBeAwaitedAndReturnsItsCannedResult() async {
        let stub = StubTokenRefresher(result: .success(accessToken: "A", refreshToken: "R"))
        let result = await stub.refresh(refreshToken: "old")
        guard case let .success(accessToken, refreshToken) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(accessToken, "A")
        XCTAssertEqual(refreshToken, "R")
        XCTAssertEqual(stub.callCount, 1)
    }
}
