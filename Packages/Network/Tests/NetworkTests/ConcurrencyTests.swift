import Foundation
import XCTest
@testable import Network

/// Concurrent requests do not share mutable state.
final class ConcurrencyTests: StubbedClientTestCase {
    func testTwoConcurrentRequestsEachGetTheirOwnResponse() async throws {
        // Each response echoes the id from the request path.
        StubStore.shared.setHandler { request in
            let id = Int(request.url?.lastPathComponent ?? "") ?? -1
            let body = Data("{\"id\":\(id),\"name\":\"widget-\(id)\"}".utf8)
            return .response(status: 200, body: body)
        }
        let client = makeClient()

        try await withThrowingTaskGroup(of: (Int, Widget).self) { group in
            for id in 0 ..< 40 {
                group.addTask {
                    let widget: Widget = try await client.send(APIRequest(method: .get, path: "/widgets/\(id)"))
                    return (id, widget)
                }
            }
            var seen = Set<Int>()
            for try await (id, widget) in group {
                XCTAssertEqual(widget, Widget(id: id, name: "widget-\(id)"), "response leaked across requests")
                seen.insert(id)
            }
            XCTAssertEqual(seen, Set(0 ..< 40))
        }
    }

    func testConcurrentRequestsWithDistinctInterceptorChainsDoNotInterfere() async throws {
        StubStore.shared.setHandler { _ in .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8)) }
        let session = try XCTUnwrap(session)
        let environment = environment
        let logger = try XCTUnwrap(logger)

        try await withThrowingTaskGroup(of: [String].self) { group in
            for _ in 0 ..< 20 {
                group.addTask {
                    let recorder = CallRecorder()
                    let scoped = URLSessionAPIClient(
                        session: session,
                        interceptors: [
                            RecordingInterceptor(name: "A", recorder: recorder),
                            RecordingInterceptor(name: "B", recorder: recorder),
                        ],
                        environment: environment,
                        logger: logger
                    )
                    _ = try await scoped.send(APIRequest(method: .get, path: "/x")) as Widget
                    return recorder.calls
                }
            }
            for try await calls in group {
                XCTAssertEqual(calls, ["A.adapt", "B.adapt", "A.didReceive", "B.didReceive"])
            }
        }
    }
}
