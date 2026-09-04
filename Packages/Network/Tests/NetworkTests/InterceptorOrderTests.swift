import Foundation
import XCTest
@testable import Network

/// Interceptors run `adapt()` in registration order and `didReceive()` in the
/// same order — proven with three interceptors.
final class InterceptorOrderTests: StubbedClientTestCase {
    func testAdaptThenDidReceiveRunInRegistrationOrder() async throws {
        let recorder = CallRecorder()
        let interceptors = [
            RecordingInterceptor(name: "A", recorder: recorder, stampHeader: true),
            RecordingInterceptor(name: "B", recorder: recorder, stampHeader: true),
            RecordingInterceptor(name: "C", recorder: recorder, stampHeader: true),
        ]
        StubStore.shared.setHandler { request in
            // adapt order is also visible on the wire
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Chain"), "A,B,C")
            return .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8))
        }

        _ = try await makeClient(interceptors: interceptors)
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertEqual(
            recorder.calls,
            ["A.adapt", "B.adapt", "C.adapt", "A.didReceive", "B.didReceive", "C.didReceive"]
        )
    }

    func testDidReceiveStillRunsInOrderOnErrorStatus() async {
        let recorder = CallRecorder()
        let interceptors = [
            RecordingInterceptor(name: "A", recorder: recorder),
            RecordingInterceptor(name: "B", recorder: recorder),
            RecordingInterceptor(name: "C", recorder: recorder),
        ]
        StubStore.shared.setHandler { _ in .response(status: 500, body: Data("boom".utf8)) }

        await assertThrowsAsync {
            _ = try await self.makeClient(interceptors: interceptors)
                .send(APIRequest(method: .get, path: "/x")) as Widget
        }

        XCTAssertEqual(
            recorder.calls,
            ["A.adapt", "B.adapt", "C.adapt", "A.didReceive", "B.didReceive", "C.didReceive"]
        )
    }

    func testRetryIsAskedInRegistrationOrderAndStopsAtTheFirstRetryLeavingAdaptDidReceiveOrderIntact() async throws {
        let recorder = CallRecorder()
        let attempts = LockedCounter()
        StubStore.shared.setHandler { _ in
            attempts.increment() == 1
                ? .response(status: 401)
                : .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8))
        }
        let interceptors = [
            RecordingInterceptor(name: "A", recorder: recorder), // default .doNotRetry
            RecordingInterceptor(name: "B", recorder: recorder, onRetry: { .retry($0) }),
            RecordingInterceptor(name: "C", recorder: recorder, onRetry: { .retry($0) }),
        ]

        _ = try await makeClient(interceptors: interceptors)
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertEqual(
            recorder.calls,
            [
                "A.adapt", "B.adapt", "C.adapt",
                "A.didReceive", "B.didReceive", "C.didReceive", // 401
                "A.retry", "B.retry", // A declines, B retries -> C never asked; no re-adapt on resend
                "A.didReceive", "B.didReceive", "C.didReceive", // retried 200
            ]
        )
    }

    func testAFirstInterceptorThatRetriesShortCircuitsTheRest() async throws {
        let recorder = CallRecorder()
        let attempts = LockedCounter()
        StubStore.shared.setHandler { _ in
            attempts.increment() == 1
                ? .response(status: 401)
                : .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8))
        }
        let interceptors = [
            RecordingInterceptor(name: "A", recorder: recorder, onRetry: { .retry($0) }),
            RecordingInterceptor(name: "B", recorder: recorder, onRetry: { .retry($0) }),
        ]

        _ = try await makeClient(interceptors: interceptors)
            .send(APIRequest(method: .get, path: "/x")) as Widget

        XCTAssertEqual(recorder.calls.filter { $0 == "A.retry" }.count, 1)
        XCTAssertFalse(recorder.calls.contains("B.retry"), "first .retry short-circuits the chain")
    }
}
