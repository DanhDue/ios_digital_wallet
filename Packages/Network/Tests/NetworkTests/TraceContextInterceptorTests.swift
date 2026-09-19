import Core
import Foundation
import XCTest
@testable import Network

final class TraceContextInterceptorTests: XCTestCase {
    private final class StubTraceContextProvider: TraceContextProviding, @unchecked Sendable {
        var headerToReturn: String?

        init(headerToReturn: String? = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01") {
            self.headerToReturn = headerToReturn
        }

        func traceparentHeader() -> String? {
            headerToReturn
        }
    }

    // UC-3.1: TraceContextInterceptor adds a well-formed traceparent header
    func testAdaptAddsWellFormedTraceparentHeader() async throws {
        let provider = StubTraceContextProvider()
        let interceptor = TraceContextInterceptor(provider: provider)
        var request = URLRequest(url: requireURL("https://example.com/v1/cards"))
        request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")
        request.setValue("custom-value", forHTTPHeaderField: "X-Custom")

        let adapted = await interceptor.adapt(request)

        let traceparent = try XCTUnwrap(adapted.value(forHTTPHeaderField: "traceparent"))
        let regex = try NSRegularExpression(pattern: "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")
        let range = NSRange(location: 0, length: traceparent.utf16.count)
        XCTAssertEqual(regex.numberOfMatches(in: traceparent, range: range), 1)

        // No other header of the original request is modified
        XCTAssertEqual(adapted.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        XCTAssertEqual(adapted.value(forHTTPHeaderField: "X-Custom"), "custom-value")
    }

    // UC-3.2: A request that already carries traceparent is not double-stamped
    func testAdaptDoesNotDoubleStampRequestWithExistingTraceparent() async {
        let sampleHeader = "00-newtraceid00000000000000000000000-newspanid000000-01"
        let provider = StubTraceContextProvider(headerToReturn: sampleHeader)
        let interceptor = TraceContextInterceptor(provider: provider)
        var request = URLRequest(url: requireURL("https://example.com/v1/cards"))
        let existingTraceparent = "00-existingtraceid1111111111111111-existingspan1111-01"
        request.setValue(existingTraceparent, forHTTPHeaderField: "traceparent")

        let adapted = await interceptor.adapt(request)

        XCTAssertEqual(adapted.value(forHTTPHeaderField: "traceparent"), existingTraceparent)
    }

    // UC-3.2: A nil trace context leaves the request untouched rather than emitting a malformed header
    func testAdaptWithNilTraceContextLeavesRequestUntouched() async {
        let provider = StubTraceContextProvider(headerToReturn: nil)
        let interceptor = TraceContextInterceptor(provider: provider)
        var request = URLRequest(url: requireURL("https://example.com/v1/cards"))
        request.setValue("Bearer test-token", forHTTPHeaderField: "Authorization")

        let adapted = await interceptor.adapt(request)

        XCTAssertNil(adapted.value(forHTTPHeaderField: "traceparent"))
        XCTAssertEqual(adapted.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    }

    // UC-3.4: didReceive reports status without body or timing, by design
    func testDidReceiveReportsStatusWithoutBodyOrTimingByDesign() throws {
        let provider = StubTraceContextProvider()
        let logger = SpyLogger()
        let interceptor = TraceContextInterceptor(provider: provider, logger: logger)

        let response = try XCTUnwrap(HTTPURLResponse(
            url: requireURL("https://example.com/v1/cards"),
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        ))

        interceptor.didReceive(response)

        let errorLogs = logger.messages(level: "error")
        XCTAssertTrue(errorLogs.contains { $0.contains("500") })
    }

    func testDidReceiveWithNoLoggerReturnsWithoutThrowing() throws {
        let provider = StubTraceContextProvider()
        let interceptor = TraceContextInterceptor(provider: provider)

        let response = try XCTUnwrap(HTTPURLResponse(
            url: requireURL("https://example.com/v1/cards"),
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        ))

        interceptor.didReceive(response)
    }

    // UC-3.3: Network reaches trace context only through the Core seam
    func testNetworkPackageManifestDeclaresCoreOnlyAndNoD3NexusLoggingImport() throws {
        guard let prefix = #filePath.components(
            separatedBy: "Tests/NetworkTests/TraceContextInterceptorTests.swift"
        ).first else {
            XCTFail("Could not locate Network package root")
            return
        }
        let packageSwiftPath = prefix + "Package.swift"
        let manifest = try String(contentsOfFile: packageSwiftPath)
        XCTAssertTrue(manifest.contains(".product(name: \"Core\", package: \"Core\")"))
        XCTAssertFalse(manifest.contains("D3NexusLogging"))
    }
}
