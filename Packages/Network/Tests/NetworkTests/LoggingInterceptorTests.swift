import Core
import Foundation
import XCTest
@testable import Network

/// `LoggingInterceptor` logs the request at `info` and error responses at
/// `error`; `HTTPStatusCode` classifies by range; `AppEnvironment` exposes
/// placeholder headers.
final class LoggingInterceptorTests: XCTestCase {
    func testAdaptLogsRequestLineAtInfoAndReturnsRequestUnchanged() async {
        let logger = SpyLogger()
        let interceptor = LoggingInterceptor(logger: logger)
        var request = URLRequest(url: requireURL("https://api.example.com/things"))
        request.httpMethod = "GET"

        let result = await interceptor.adapt(request)

        XCTAssertEqual(result, request)
        XCTAssertTrue(logger.messages(level: "info").contains { $0.contains("GET") && $0.contains("/things") })
    }

    func testDidReceiveLogsErrorStatusAtErrorLevel() throws {
        let logger = SpyLogger()
        let interceptor = LoggingInterceptor(logger: logger)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: requireURL("https://api.example.com/things"),
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        ))

        interceptor.didReceive(response)

        XCTAssertTrue(logger.messages(level: "error").contains { $0.contains("503") })
        XCTAssertTrue(logger.messages(level: "info").isEmpty)
    }

    func testDidReceiveLogsSuccessStatusAtInfoLevel() throws {
        let logger = SpyLogger()
        let interceptor = LoggingInterceptor(logger: logger)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: requireURL("https://api.example.com/things"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        ))

        interceptor.didReceive(response)

        XCTAssertTrue(logger.messages(level: "info").contains { $0.contains("200") })
        XCTAssertTrue(logger.messages(level: "error").isEmpty)
    }

    func testHTTPStatusCodeRangeClassification() {
        XCTAssertTrue(HTTPStatusCode.isSuccess(200))
        XCTAssertTrue(HTTPStatusCode.isSuccess(299))
        XCTAssertFalse(HTTPStatusCode.isSuccess(300))
        XCTAssertTrue(HTTPStatusCode.isClientError(400))
        XCTAssertTrue(HTTPStatusCode.isClientError(499))
        XCTAssertFalse(HTTPStatusCode.isClientError(500))
        XCTAssertTrue(HTTPStatusCode.isServerError(500))
        XCTAssertTrue(HTTPStatusCode.isServerError(599))
        XCTAssertFalse(HTTPStatusCode.isServerError(600))
        XCTAssertEqual(HTTPStatusCode.unauthorized.rawValue, 401)
        XCTAssertEqual(HTTPStatusCode.noContent.rawValue, 204)
    }

    func testAppEnvironmentDefaultHeadersCarryPlaceholderValues() {
        for env in AppEnvironment.allCases {
            let headers = env.defaultHeaders
            XCTAssertEqual(headers["Accept"], "application/json")
            XCTAssertEqual(headers["X-App-Environment"], env.rawValue)
        }
    }
}
