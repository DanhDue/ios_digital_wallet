import Core
import Foundation
import XCTest
@testable import Network

/// `RefreshingAuthInterceptor` driven end-to-end through a stubbed
/// `URLSessionAPIClient`: single-flight refresh on a 401, the one permitted
/// resend carrying a fresh bearer + `X-Auth-Retry: 1`, and the three-case
/// force-logout ladder (plus the non-logout transient path).
final class RefreshingAuthInterceptorTests: StubbedClientTestCase {
    private let okBody = Data("{\"id\":1,\"name\":\"ok\"}".utf8)
    private let refreshEndpoint = RefreshTokenEndpoint(pathSuffix: "auth/refresh")

    private func makeInterceptor(
        session: SessionManaging,
        refresher: TokenRefresher,
        coordinator: RefreshCoordinator = RefreshCoordinator()
    ) -> RefreshingAuthInterceptor {
        RefreshingAuthInterceptor(
            session: session,
            refresher: refresher,
            coordinator: coordinator,
            authEventSink: sink,
            refreshEndpoint: refreshEndpoint
        )
    }

    /// 401 for a marker-less request, `answer` for a request that carries
    /// `X-Auth-Retry: 1` (also asserting its `Authorization` header).
    private func setStub(resendBearer: String, answer: @escaping @Sendable () -> StubOutcome) {
        StubStore.shared.setHandler { request in
            if request.value(forHTTPHeaderField: AuthHeader.retry) == AuthHeader.retryValue {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(resendBearer)")
                return answer()
            }
            return .response(status: 401)
        }
    }

    // MARK: - Happy path

    func testFirst401RefreshesThenResendsWithNewBearerAndRetryMarkerThen200() async throws {
        let session = SessionManager(accessToken: "A1")
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.success(accessToken: "A2", refreshToken: "R2"))
        let body = okBody
        setStub(resendBearer: "A2") { .response(status: 200, body: body) }

        let client = makeClient(interceptors: [makeInterceptor(session: session, refresher: refresher)])
        let widget: Widget = try await client.send(APIRequest(method: .get, path: "/me"))

        XCTAssertEqual(widget, Widget(id: 1, name: "ok"))
        XCTAssertEqual(session.accessToken, "A2")
        XCTAssertEqual(session.refreshToken, "R2", "server rotated the refresh token")
        XCTAssertEqual(refresher.callCount, 1)
        XCTAssertEqual(refresher.lastRefreshToken, "R1")
        XCTAssertEqual(sink.callCount, 0)
        XCTAssertEqual(StubStore.shared.startCount, 2, "original + one resend")
    }

    func testRotationWithNilRefreshTokenLeavesTheStoredRefreshTokenIntact() async throws {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.success(accessToken: "A2", refreshToken: nil))
        let body = okBody
        setStub(resendBearer: "A2") { .response(status: 200, body: body) }

        _ = try await makeClient(interceptors: [makeInterceptor(session: session, refresher: refresher)])
            .send(APIRequest(method: .get, path: "/me")) as Widget

        XCTAssertEqual(session.accessToken, "A2")
        XCTAssertEqual(session.refreshToken, "R1", "nil rotation keeps the existing refresh token")
    }

    // MARK: - Case 1 — persistent failure

    func testRetriedRequestStill401FiresRetryStillUnauthorizedAndClearsWithoutAskingRefreshAgain() async {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.success(accessToken: "A2", refreshToken: "R2"))
        StubStore.shared.setHandler { _ in .response(status: 401) }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [self.makeInterceptor(session: session, refresher: refresher)])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.reasons, [.retryStillUnauthorized])
        XCTAssertNil(session.accessToken, "session cleared")
        XCTAssertNil(session.refreshToken, "session cleared")
        XCTAssertEqual(refresher.callCount, 1, "Case 1 short-circuits before the refresh ladder step")
        XCTAssertEqual(StubStore.shared.startCount, 2, "original + one resend, no third attempt")
    }

    // MARK: - Case 2a — invalid grant

    func testRefresherInvalidGrantForcesRefreshFailedLogoutAndClearsSession() async {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.failure(.invalidGrant))
        StubStore.shared.setHandler { _ in .response(status: 401) }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [self.makeInterceptor(session: session, refresher: refresher)])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.reasons, [.refreshFailed])
        XCTAssertNil(session.accessToken)
        XCTAssertNil(session.refreshToken)
        XCTAssertEqual(refresher.callCount, 1)
        XCTAssertEqual(StubStore.shared.startCount, 1, "no resend")
    }

    // MARK: - Case 2b — the refresh endpoint itself 401s

    func testA401FromTheRefreshEndpointIsTreatedAsADeadSessionAndNeverCallsRefresher() async {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.success(accessToken: "A2", refreshToken: "R2"))
        StubStore.shared.setHandler { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "no bearer on the refresh call")
            return .response(status: 401)
        }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [self.makeInterceptor(session: session, refresher: refresher)])
                .send(APIRequest(method: .post, path: "/auth/refresh")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.reasons, [.refreshFailed])
        XCTAssertNil(session.accessToken)
        XCTAssertNil(session.refreshToken)
        XCTAssertEqual(refresher.callCount, 0, "refresher never called")
        XCTAssertEqual(StubStore.shared.startCount, 1)
    }

    // MARK: - Case 3 — missing refresh token

    func testA401WithNoRefreshTokenFiresMissingRefreshTokenAndNeverCallsRefresher() async {
        let session = SessionManager(accessToken: "A1") // refreshToken stays nil
        let refresher = SpyTokenRefresher(.success(accessToken: "A2", refreshToken: "R2"))
        StubStore.shared.setHandler { _ in .response(status: 401) }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [self.makeInterceptor(session: session, refresher: refresher)])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.reasons, [.missingRefreshToken])
        XCTAssertNil(session.accessToken, "session cleared")
        XCTAssertEqual(refresher.callCount, 0)
        XCTAssertEqual(StubStore.shared.startCount, 1)
    }

    // MARK: - Transient — no logout

    func testRefresherTransientDoesNotLogOutAndLeavesTheSessionIntact() async {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.failure(.transient))
        StubStore.shared.setHandler { _ in .response(status: 401) }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [self.makeInterceptor(session: session, refresher: refresher)])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.callCount, 0, "transient never notifies the sink")
        XCTAssertEqual(session.accessToken, "A1", "session intact")
        XCTAssertEqual(session.refreshToken, "R1", "session intact")
        XCTAssertEqual(refresher.callCount, 1)
        XCTAssertEqual(StubStore.shared.startCount, 1)
    }

    func testATransientRefreshDoesNotPoisonALaterSuccessfulRefresh() async throws {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(delay: .zero) { call in
            call == 1 ? .failure(.transient) : .success(accessToken: "A2", refreshToken: "R2")
        }
        let coordinator = RefreshCoordinator()
        let body = okBody
        setStub(resendBearer: "A2") { .response(status: 200, body: body) }
        let client = makeClient(interceptors: [
            makeInterceptor(session: session, refresher: refresher, coordinator: coordinator),
        ])

        await assertThrowsAsync {
            _ = try await client.send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }
        XCTAssertEqual(session.accessToken, "A1", "still intact after the transient failure")

        let widget: Widget = try await client.send(APIRequest(method: .get, path: "/me"))

        XCTAssertEqual(widget, Widget(id: 1, name: "ok"))
        XCTAssertEqual(session.accessToken, "A2")
        XCTAssertEqual(session.refreshToken, "R2")
        XCTAssertEqual(refresher.callCount, 2)
    }

    // MARK: - Whitelist / bearer-skip

    func testAuthRequirementNoneAttachesNoBearerAndStripsTheMarker() async throws {
        let session = SessionManager(accessToken: "A1")
        let refresher = SpyTokenRefresher(.failure(.transient))
        let body = okBody
        StubStore.shared.setHandler { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "public endpoint gets no bearer")
            XCTAssertNil(request.value(forHTTPHeaderField: AuthHeader.requirement), "marker stripped before the wire")
            return .response(status: 200, body: body)
        }

        _ = try await makeClient(interceptors: [makeInterceptor(session: session, refresher: refresher)])
            .send(APIRequest(method: .post, path: "/login", authRequirement: .none)) as Widget
    }

    func testRefreshEndpointRequestsNeverGetABearerFromAdapt() async throws {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.failure(.transient))
        let body = okBody
        StubStore.shared.setHandler { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return .response(status: 200, body: body)
        }

        _ = try await makeClient(interceptors: [makeInterceptor(session: session, refresher: refresher)])
            .send(APIRequest(method: .post, path: "/auth/refresh")) as Widget
    }

    // MARK: - Concurrency

    func testThreeRequestsRacingTheSameExpiredTokenRefreshExactlyOnce() async throws {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(
            delay: .milliseconds(30),
            results: { _ in .success(accessToken: "A2", refreshToken: "R2") }
        )
        let coordinator = RefreshCoordinator()
        let body = okBody
        setStub(resendBearer: "A2") { .response(status: 200, body: body) }
        let client = makeClient(interceptors: [
            makeInterceptor(session: session, refresher: refresher, coordinator: coordinator),
        ])

        try await withThrowingTaskGroup(of: Widget.self) { group in
            for _ in 0 ..< 3 {
                group.addTask { try await client.send(APIRequest(method: .get, path: "/me")) }
            }
            var count = 0
            for try await widget in group {
                XCTAssertEqual(widget, Widget(id: 1, name: "ok"))
                count += 1
            }
            XCTAssertEqual(count, 3)
        }

        XCTAssertEqual(refresher.callCount, 1, "single-flight: one refresh for the whole wave")
    }

    // MARK: - .transport reason

    func testTransportReasonIsANoOp() async {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(.failure(.invalidGrant))
        let interceptor = makeInterceptor(session: session, refresher: refresher)
        let request = URLRequest(url: requireURL("https://api.example.com/me"))

        let decision = await interceptor.retry(request, dueTo: .transport(URLError(.notConnectedToInternet)))

        guard case .doNotRetry = decision else {
            return XCTFail("expected .doNotRetry, got \(decision)")
        }
        XCTAssertEqual(sink.callCount, 0)
        XCTAssertEqual(session.accessToken, "A1")
        XCTAssertEqual(refresher.callCount, 0)
    }
}
