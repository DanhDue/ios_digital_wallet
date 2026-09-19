import Core
import D3NexusLogging
import Foundation
import Pulse
import XCTest
@testable import iOSDigitalWallet

private struct StubResponse: Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var stubs: [URL: Result<StubResponse, Error>] = [:]

    static func reset() {
        lock.withLock { stubs.removeAll() }
    }

    static func stub(
        url: URL,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        let stubResponse = StubResponse(statusCode: statusCode, headers: headers, body: body)
        lock.withLock { stubs[url] = .success(stubResponse) }
    }

    static func stubError(url: URL, error: Error) {
        lock.withLock { stubs[url] = .failure(error) }
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let stub = Self.lock.withLock { Self.stubs[url] }

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        switch stub {
        case let .success(response):
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotParseResponse))
                return
            }
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.body)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func requireURL(_ string: String) -> URL {
    guard let url = URL(string: string) else {
        fatalError("Invalid test URL: \(string)")
    }
    return url
}

final class PulseCaptureTests: XCTestCase {
    private var store: LoggerStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pulse-test-\(UUID().uuidString).pulse")
        store = try LoggerStore(storeURL: storeURL, options: [.create, .inMemory, .synchronous])
        URLProtocolStub.reset()
    }

    override func tearDownWithError() throws {
        URLProtocolStub.reset()
        store = nil
        try super.tearDownWithError()
    }

    // UC-9.1: The instrumented session records a completed transaction
    func testCapturedEntryRecordsDurationByteCountAndDecodedBody() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]

        let session = PulseSessionFactory.makeURLSession(
            configuration: config,
            store: store
        )

        let targetURL = requireURL("https://api.example.com/items")
        let jsonResponse = """
        {"status":"success","count":42}
        """
        URLProtocolStub.stub(url: targetURL, statusCode: 200, body: Data(jsonResponse.utf8))

        var request = URLRequest(url: targetURL)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertFalse(data.isEmpty)

        // Wait brief tick for async event handler in Pulse
        try await Task.sleep(for: .milliseconds(150))

        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)

        let task = tasks[0]
        XCTAssertEqual(task.statusCode, 200)
        XCTAssertGreaterThanOrEqual(task.duration, 0)
        XCTAssertGreaterThan(task.responseBodySize, 0)

        let responseBodyData = try XCTUnwrap(task.responseBody?.data)
        let decoded = try JSONSerialization.jsonObject(with: responseBodyData) as? [String: Any]
        XCTAssertEqual(decoded?["status"] as? String, "success")
        XCTAssertEqual(decoded?["count"] as? Int, 42)

        let curl = PulseSessionFactory.cURLDescription(for: task)
        XCTAssertTrue(curl.contains("curl -v"))
        XCTAssertTrue(curl.contains("https://api.example.com/items"))
    }

    // UC-9.2: Captured network bodies and headers are redacted before they reach storage
    func testCapturedNetworkBodiesAndHeadersAreRedactedBeforeReachingStorage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]

        let session = PulseSessionFactory.makeURLSession(
            configuration: config,
            store: store,
            redactor: Redactor()
        )

        let targetURL = requireURL("https://api.example.com/payment")
        let rawCard = "4111111111111234"
        let secretToken = "Bearer secret_token_xyz123"
        let jsonResponse = """
        {"card":"\(rawCard)","owner":"John"}
        """
        URLProtocolStub.stub(url: targetURL, statusCode: 200, body: Data(jsonResponse.utf8))

        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.setValue(secretToken, forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{\"amount\":100}".utf8)

        _ = try await session.data(for: request)

        try await Task.sleep(for: .milliseconds(150))

        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)

        let task = tasks[0]
        let headers = task.originalRequest?.headers ?? [:]
        let authHeader = headers["Authorization"] ?? headers["authorization"]

        XCTAssertEqual(authHeader, "[REDACTED]")
        XCTAssertFalse(headers.values.contains { $0.contains("secret_token_xyz123") })

        let responseBodyData = try XCTUnwrap(task.responseBody?.data)
        let responseBodyString = String(data: responseBodyData, encoding: .utf8) ?? ""

        XCTAssertFalse(responseBodyString.contains(rawCard))
        XCTAssertTrue(responseBodyString.contains("****") || responseBodyString.contains("[REDACTED]"))
    }

    // UC-9.3: A transport failure is captured without destabilising the request pipeline
    func testConnectionTimeoutRecordedWithoutDestabilisingCaller() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]

        let session = PulseSessionFactory.makeURLSession(
            configuration: config,
            store: store
        )

        let targetURL = requireURL("https://api.example.com/timeout")
        URLProtocolStub.stubError(url: targetURL, error: URLError(.timedOut))

        let request = URLRequest(url: targetURL)

        do {
            _ = try await session.data(for: request)
            XCTFail("Expected timeout error")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }

        try await Task.sleep(for: .milliseconds(150))

        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].state, .failure)
        XCTAssertEqual(tasks[0].errorCode, Int32(URLError.timedOut.rawValue))
    }

    // UC-9.3: Removing the instrumentation leaves the network stack fully functional
    func testPlainURLSessionRollbackPathWorksIdentically() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        let plainSession = URLSession(configuration: config)

        let targetURL = requireURL("https://api.example.com/plain")
        URLProtocolStub.stub(url: targetURL, statusCode: 200, body: Data("ok".utf8))

        let (data, response) = try await plainSession.data(for: URLRequest(url: targetURL))
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
    }

    #if DEBUG
        // UC-4.1: PulseAppender sets respectsModuleToggle = true
        func testPulseAppenderRespectsModuleToggle() throws {
            let appender = PulseAppender(store: store)
            XCTAssertEqual(appender.id, "pulse")
            XCTAssertTrue(appender.respectsModuleToggle)

            let record = LogRecord(
                module: "TestModule",
                level: .info,
                message: "Hello Pulse",
                timestamp: Date(),
                traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
                spanId: "00f067aa0ba902b7",
                parentSpanId: nil,
                errorDescription: nil,
                metadata: ["key": "val"]
            )

            appender.append(record)

            let messages = try store.allMessages()
            XCTAssertEqual(messages.count, 1)
            XCTAssertEqual(messages[0].text, "Hello Pulse")
            XCTAssertEqual(messages[0].label, "TestModule")
        }
    #endif
}
