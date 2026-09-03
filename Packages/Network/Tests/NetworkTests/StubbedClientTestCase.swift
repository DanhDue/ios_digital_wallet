import Core
import Foundation
import XCTest
@testable import Network

/// Shared harness for tests that drive `URLSessionAPIClient` through the
/// `URLProtocol` stub. Registers / unregisters the stub per test.
class StubbedClientTestCase: XCTestCase {
    var session: URLSession!
    var logger: SpyLogger!
    var sink: SpyAuthEventSink!
    let environment = FixedEnvironment(baseURL: requireURL("https://api.example.com"))

    override func setUp() {
        super.setUp()
        StubStore.shared.reset()
        session = StubStore.makeSession()
        logger = SpyLogger()
        sink = SpyAuthEventSink()
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        logger = nil
        sink = nil
        StubStore.shared.reset()
        super.tearDown()
    }

    func makeClient(interceptors: [RequestInterceptor] = []) -> URLSessionAPIClient {
        URLSessionAPIClient(
            session: session,
            interceptors: interceptors,
            environment: environment,
            logger: logger,
            authEventSink: sink
        )
    }
}
