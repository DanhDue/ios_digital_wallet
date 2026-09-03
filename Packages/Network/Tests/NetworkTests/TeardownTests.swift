import Foundation
import XCTest
@testable import Network

/// Resource teardown: the client and its `URLSession` (hence the underlying data
/// task) are released once a call completes or throws — nothing keeps them
/// alive.
final class TeardownTests: XCTestCase {
    override func tearDown() {
        StubStore.shared.reset()
        super.tearDown()
    }

    func testClientAndSessionAreReleasedAfterASuccessfulCall() async throws {
        StubStore.shared.reset()
        StubStore.shared.setHandler { _ in .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8)) }

        weak var weakSession: URLSession?
        weak var weakClient: URLSessionAPIClient?

        try await { () async throws in
            let session = StubStore.makeSession()
            let client = URLSessionAPIClient(
                session: session,
                environment: FixedEnvironment(baseURL: requireURL("https://api.example.com")),
                logger: SpyLogger()
            )
            weakSession = session
            weakClient = client
            _ = try await client.send(APIRequest(method: .get, path: "/x")) as Widget
            session.finishTasksAndInvalidate()
        }()

        // give URLSession's delegate queue a beat to drop its retain
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(weakClient, "client leaked")
        XCTAssertNil(weakSession, "session / data task leaked")
    }

    func testClientAndSessionAreReleasedAfterAThrowingCall() async throws {
        StubStore.shared.reset()
        StubStore.shared.setHandler { _ in .failure(URLError(.timedOut)) }

        weak var weakSession: URLSession?
        weak var weakClient: URLSessionAPIClient?

        await { () async in
            let session = StubStore.makeSession()
            let client = URLSessionAPIClient(
                session: session,
                environment: FixedEnvironment(baseURL: requireURL("https://api.example.com")),
                logger: SpyLogger()
            )
            weakSession = session
            weakClient = client
            await assertThrowsAsync {
                _ = try await client.send(APIRequest(method: .get, path: "/x")) as Widget
            }
            session.finishTasksAndInvalidate()
        }()

        try await Task.sleep(for: .milliseconds(50))
        XCTAssertNil(weakClient, "client leaked after throw")
        XCTAssertNil(weakSession, "session / data task leaked after throw")
    }
}
