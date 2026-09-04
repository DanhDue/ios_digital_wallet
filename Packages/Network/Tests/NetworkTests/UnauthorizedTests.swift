import Core
import Foundation
import XCTest
@testable import Network

/// With an `AuthTokenInterceptor` installed and no refresh interceptor, a bare
/// `401` notifies `AuthEventSink` exactly once **per response** with
/// `.unauthorized` and surfaces `NetworkError.unauthorized` — the client itself
/// no longer notifies the sink from `validate`.
final class UnauthorizedTests: StubbedClientTestCase {
    private func authClient() -> URLSessionAPIClient {
        makeClient(interceptors: [
            AuthTokenInterceptor(session: SessionManager(accessToken: nil), authEventSink: sink),
        ])
    }

    func testSingle401CallsOnUnauthorizedExactlyOnceAndSurfacesError() async {
        StubStore.shared.setHandler { _ in .response(status: 401, body: Data("unauth".utf8)) }

        await assertThrowsAsync {
            _ = try await self.authClient().send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.reasons, [.unauthorized])
        XCTAssertEqual(StubStore.shared.startCount, 1, "bare 401 → no resend")
    }

    func testRetryOnceWrapperOnPersistent401CallsOnUnauthorizedOncePerResponse() async {
        // Every attempt gets its own distinct 401 response -> 2 responses -> 2 calls.
        StubStore.shared.setHandler { _ in .response(status: 401) }
        let client = RetryOnceClient(wrapped: authClient())

        await assertThrowsAsync {
            _ = try await client.send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(sink.callCount, 2, "one call per distinct 401 response, not per attempt")
        XCTAssertEqual(sink.reasons, [.unauthorized, .unauthorized])
        XCTAssertEqual(StubStore.shared.startCount, 2, "wrapper retried exactly once")
    }

    func testRetryOnceWrapper401ThenSuccessCallsOnUnauthorizedExactlyOnce() async throws {
        let responses = LockedCounter()
        StubStore.shared.setHandler { _ in
            responses.increment() == 1
                ? .response(status: 401)
                : .response(status: 200, body: Data("{\"id\":9,\"name\":\"ok\"}".utf8))
        }
        let client = RetryOnceClient(wrapped: authClient())

        let widget: Widget = try await client.send(APIRequest(method: .get, path: "/me"))

        XCTAssertEqual(widget, Widget(id: 9, name: "ok"))
        XCTAssertEqual(sink.callCount, 1, "only one 401 response occurred")
    }

    func testNo401MeansNoOnUnauthorizedCall() async throws {
        StubStore.shared.setHandler { _ in .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8)) }

        _ = try await authClient().send(APIRequest(method: .get, path: "/me")) as Widget

        XCTAssertEqual(sink.callCount, 0)
    }
}

/// Tiny thread-safe counter for stub handlers.
final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    /// Increments and returns the new value.
    @discardableResult
    func increment() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}
