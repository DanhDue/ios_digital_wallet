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
