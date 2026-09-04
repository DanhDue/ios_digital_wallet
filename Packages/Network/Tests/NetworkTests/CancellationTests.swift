import Core
import Foundation
import XCTest
@testable import Network

/// A request cancelled mid-flight throws `CancellationError` and runs no
/// `interceptor.didReceive`.
final class CancellationTests: StubbedClientTestCase {
    func testCancelledRequestThrowsCancellationErrorAndSkipsDidReceive() async throws {
        let recorder = CallRecorder()
        StubStore.shared.delay = .seconds(5)
        StubStore.shared.setHandler { _ in .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8)) }
        let client = makeClient(interceptors: [RecordingInterceptor(name: "A", recorder: recorder)])

        let task = Task { () throws -> Widget in
            try await client.send(APIRequest(method: .get, path: "/slow"))
        }

        // wait until the load has actually begun, then cancel
        try await waitUntil { StubStore.shared.startCount == 1 }
        task.cancel()

        await assertThrowsAsync {
            try await task.value
        } onError: { error in
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }
        XCTAssertFalse(recorder.calls.contains("A.didReceive"), "didReceive must not run on cancellation")
        XCTAssertTrue(recorder.calls.contains("A.adapt"))
    }

    /// Cancelling `send` while `RefreshingAuthInterceptor` is awaiting the
    /// coordinator's refresh surfaces `CancellationError` — never mapped to
    /// `.unauthorized`, never swallowed — and touches neither the sink nor the
    /// session. The refresh itself completes (its unstructured `Task` is not a
    /// child of the cancelled one); the cancellation is caught by
    /// `URLSessionAPIClient`'s `Task.checkCancellation()` before the resend.
    func testCancellingDuringTheRefreshAwaitThrowsCancellationError() async throws {
        let session = SessionManager()
        session.update(accessToken: "A1", refreshToken: "R1")
        let refresher = SpyTokenRefresher(
            delay: .milliseconds(200),
            results: { _ in .success(accessToken: "A2", refreshToken: "R2") }
        )
        let interceptor = RefreshingAuthInterceptor(
            session: session,
            refresher: refresher,
            coordinator: RefreshCoordinator(),
            authEventSink: sink,
            refreshEndpoint: RefreshTokenEndpoint(pathSuffix: "auth/refresh")
        )
        StubStore.shared.setHandler { _ in .response(status: 401) }
        let client = makeClient(interceptors: [interceptor])

        let task = Task { () throws -> Widget in
            try await client.send(APIRequest(method: .get, path: "/me"))
        }

        try await waitUntil { refresher.callCount == 1 }
        task.cancel()

        await assertThrowsAsync {
            try await task.value
        } onError: { error in
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }

        XCTAssertEqual(sink.callCount, 0, "cancellation is not a logout")
        XCTAssertNotNil(session.accessToken, "session not cleared")
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ predicate: @Sendable () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline {
                XCTFail("condition not met within \(timeout)s"); return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
