import Core
import Platform
import XCTest
@testable import iOSDigitalWallet

/// Tier A — `SessionDeepLinkGuard` (Task 8, Source Spec §4.8): reads
/// `Core.SessionManaging.accessToken` synchronously and answers the
/// host's allow / redirect / deny question. Boundary Value Analysis on the
/// two booleans that drive it (`requiresAuth`, token presence) plus the
/// `redirectTo`-configured / `redirectTo`-empty partition.
///
/// `GuardDecision` is not `Equatable` (it embeds `[any AppRoute]`), so every
/// assertion below pattern-matches instead of using `XCTAssertEqual`.
@MainActor
final class SessionDeepLinkGuardTests: XCTestCase {
    private struct FixtureRoute: AppRoute {}

    // MARK: requiresAuth: false — always .allow, token presence irrelevant

    func testRequiresAuthFalseAllowsWithoutAToken() {
        let session = SessionManager()
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [])

        guard case .allow = sut.evaluate([FixtureRoute()], requiresAuth: false) else {
            return XCTFail("expected .allow")
        }
    }

    func testRequiresAuthFalseAllowsEvenWithAToken() {
        let session = SessionManager()
        session.update(accessToken: "a-token")
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [])

        guard case .allow = sut.evaluate([FixtureRoute()], requiresAuth: false) else {
            return XCTFail("expected .allow")
        }
    }

    // MARK: requiresAuth: true, with a token — .allow

    func testRequiresAuthTrueWithATokenAllows() {
        let session = SessionManager()
        session.update(accessToken: "a-token")
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [])

        guard case .allow = sut.evaluate([FixtureRoute()], requiresAuth: true) else {
            return XCTFail("expected .allow")
        }
    }

    // MARK: requiresAuth: true, no token — boundary on redirectTo

    func testRequiresAuthTrueWithoutATokenAndAnEmptyRedirectToDenies() {
        let session = SessionManager()
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [])

        guard case .deny = sut.evaluate([FixtureRoute()], requiresAuth: true) else {
            return XCTFail("expected .deny")
        }
    }

    func testRequiresAuthTrueWithoutATokenAndAConfiguredRedirectToRedirectsAndRetainsPending() {
        let session = SessionManager()
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [AppRoutes.SettingsRoot()])

        guard case let .redirect(to, retainPending) = sut.evaluate([FixtureRoute()], requiresAuth: true) else {
            return XCTFail("expected .redirect")
        }
        XCTAssertTrue(retainPending, "the template's guard always retains a redirected link")
        XCTAssertEqual(to.count, 1)
        XCTAssertTrue(to.first is AppRoutes.SettingsRoot)
    }

    // MARK: accessToken nil vs empty string — the guard only checks presence

    func testAnEmptyStringAccessTokenStillCountsAsPresent() {
        // `SessionManaging.accessToken` is `String?`; an empty string is a
        // present (if unusual) value, not `nil` — the guard must not special-case it.
        let session = SessionManager()
        session.update(accessToken: "")
        let sut = SessionDeepLinkGuard(session: session, redirectTo: [])

        guard case .allow = sut.evaluate([FixtureRoute()], requiresAuth: true) else {
            return XCTFail("expected .allow — a present, if empty, token satisfies requiresAuth")
        }
    }
}
