import Core
import Foundation
import XCTest
@testable import Network

private let okWidgetBody = Data("{\"id\":1,\"name\":\"a\"}".utf8)

/// `URLSessionAPIClient.send` bounded-retry loop: at most one interceptor-driven
/// resend, only on a first-attempt `401`, `didReceive` for every physical
/// response, and the resent request used verbatim.
final class APIClientRetryTests: StubbedClientTestCase {
    // MARK: - Happy path

    func testFirst401ThenRetriedRequestSucceedsAndReturnsDecodedBody() async throws {
        let attempts = LockedCounter()
        StubStore.shared.setHandler { _ in
            attempts.increment() == 1
                ? .response(status: 401)
                : .response(status: 200, body: Data("{\"id\":9,\"name\":\"ok\"}".utf8))
        }
        let interceptor = RecordingInterceptor(name: "R", recorder: CallRecorder(), onRetry: { .retry($0) })

        let widget: Widget = try await makeClient(interceptors: [interceptor])
            .send(APIRequest(method: .get, path: "/me"))

        XCTAssertEqual(widget, Widget(id: 9, name: "ok"))
        XCTAssertEqual(StubStore.shared.startCount, 2, "one original + one resend")
    }

    // MARK: - Retry cap

    func testInterceptorAlwaysRetriesButSendResendsOnlyOnceThenThrowsUnauthorized() async {
        StubStore.shared.setHandler { _ in .response(status: 401) }
        let interceptor = RecordingInterceptor(name: "R", recorder: CallRecorder(), onRetry: { .retry($0) })

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [interceptor])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(StubStore.shared.startCount, 2, "capped at 2 — no third attempt")
    }

    // MARK: - No retry

    func testBare401WithNoInterceptorRetryingThrowsUnauthorizedAfterOneRequest() async {
        StubStore.shared.setHandler { _ in .response(status: 401) }
        let recorder = CallRecorder()
        let interceptor = RecordingInterceptor(name: "R", recorder: recorder) // default .doNotRetry

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: [interceptor])
                .send(APIRequest(method: .get, path: "/me")) as Widget
        } onError: { error in
            guard case NetworkError.unauthorized = error else {
                return XCTFail("expected .unauthorized, got \(error)")
            }
        }

        XCTAssertEqual(recorder.calls.filter { $0 == "R.retry" }.count, 1, "asked once, declined")
        XCTAssertEqual(StubStore.shared.startCount, 1)
    }

    // MARK: - Non-401 failures never reach `retry`

    func testNon401FailuresAreNeverPassedToRetryAndSurfaceMappedError() async {
        for status in [500, 403, 404] {
            StubStore.shared.reset()
            StubStore.shared.setHandler { _ in .response(status: status, body: Data("boom".utf8)) }
            let recorder = CallRecorder()
            let interceptor = RecordingInterceptor(name: "R", recorder: recorder, onRetry: { .retry($0) })

            await assertThrowsAsync {
                _ = try await self.makeClient(interceptors: [interceptor])
                    .send(APIRequest(method: .get, path: "/x")) as Widget
            } onError: { error in
                switch (status, error) {
                case (500, NetworkError.server(500)),
                     (403, NetworkError.client(403)),
                     (404, NetworkError.client(404)):
                    break
                default:
                    XCTFail("status \(status): unexpected \(error)")
                }
            }

            XCTAssertFalse(recorder.calls.contains("R.retry"), "status \(status): retry must not be asked")
            XCTAssertEqual(StubStore.shared.startCount, 1, "status \(status): no resend")
        }
    }

    // MARK: - 2xx first try

    func testSuccessOnFirstTryNeverAsksRetryAndDidReceiveFiresOnce() async throws {
        StubStore.shared.setHandler { _ in .response(status: 200, body: okWidgetBody) }
        let recorder = CallRecorder()
        let interceptor = RecordingInterceptor(name: "R", recorder: recorder, onRetry: { .retry($0) })

        _ = try await makeClient(interceptors: [interceptor])
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertFalse(recorder.calls.contains("R.retry"))
        XCTAssertEqual(recorder.calls.filter { $0 == "R.didReceive" }.count, 1)
    }

    // MARK: - didReceive fires for both physical responses

    func testDidReceiveFiresForBoththe401AndTheRetried200() async throws {
        let attempts = LockedCounter()
        StubStore.shared.setHandler { _ in
            attempts.increment() == 1 ? .response(status: 401) : .response(status: 200, body: okWidgetBody)
        }
        let recorder = CallRecorder()
        let interceptor = RecordingInterceptor(name: "R", recorder: recorder, onRetry: { .retry($0) })

        _ = try await makeClient(interceptors: [interceptor])
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertEqual(recorder.calls.filter { $0 == "R.didReceive" }.count, 2)
    }

    // MARK: - Verbatim resend

    func testSendResendsTheRequestReturnedByRetryVerbatimAndAddsNoMarkerItself() async throws {
        let attempts = LockedCounter()
        StubStore.shared.setHandler { request in
            if attempts.increment() == 1 {
                return .response(status: 401)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Test-Resent"), "1", "resent verbatim")
            XCTAssertNil(request.value(forHTTPHeaderField: AuthHeader.retry), "send adds no marker")
            return .response(status: 200, body: okWidgetBody)
        }
        let interceptor = RecordingInterceptor(name: "R", recorder: CallRecorder(), onRetry: { request in
            var mutated = request
            mutated.setValue("1", forHTTPHeaderField: "X-Test-Resent")
            return .retry(mutated)
        })

        _ = try await makeClient(interceptors: [interceptor])
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertEqual(StubStore.shared.startCount, 2)
    }

    // MARK: - Empty body through the retry loop

    func testEmptyResponsePathStillWorksAfterARetry() async throws {
        let attempts = LockedCounter()
        StubStore.shared.setHandler { _ in
            attempts.increment() == 1 ? .response(status: 401) : .response(status: 204)
        }
        let interceptor = RecordingInterceptor(name: "R", recorder: CallRecorder(), onRetry: { .retry($0) })

        let result: EmptyResponse = try await makeClient(interceptors: [interceptor])
            .send(APIRequest(method: .delete, path: "/x"))

        XCTAssertEqual(result, EmptyResponse())
        XCTAssertEqual(StubStore.shared.startCount, 2)
    }

    // MARK: - Cancellation between attempts

    func testCancellationBetweenAttemptsThrowsCancellationErrorAndDoesNotResend() async {
        StubStore.shared.setHandler { _ in .response(status: 401) }
        let entered = expectation(description: "retry entered")
        let gate = TestGate()
        let interceptor = RecordingInterceptor(name: "R", recorder: CallRecorder(), onRetry: { request in
            entered.fulfill()
            while !gate.isOpen {
                try? await Task.sleep(for: .milliseconds(5))
            }
            return .retry(request)
        })
        let client = makeClient(interceptors: [interceptor])

        let task = Task { () throws -> Widget in
            try await client.send(APIRequest(method: .get, path: "/me"))
        }

        await fulfillment(of: [entered], timeout: 2)
        task.cancel()
        gate.openGate()

        await assertThrowsAsync {
            try await task.value
        } onError: { error in
            XCTAssertTrue(error is CancellationError, "got \(error)")
        }

        XCTAssertEqual(StubStore.shared.startCount, 1, "second perform must not run after cancellation")
        XCTAssertEqual(sink.callCount, 0, "cancellation is not a 401 notification")
    }
}
