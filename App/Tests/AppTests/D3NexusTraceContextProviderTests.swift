import Core
import D3NexusLogging
import XCTest
@testable import iOSDigitalWallet

final class D3NexusTraceContextProviderTests: XCTestCase {
    private final class FakeLogger: LoggerProtocol, @unchecked Sendable {
        let module: String
        let traceId: String
        let spanId: String
        let parentSpanId: String?

        init(
            module: String = "Test",
            traceId: String = "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: String = "00f067aa0ba902b7",
            parentSpanId: String? = nil
        ) {
            self.module = module
            self.traceId = traceId
            self.spanId = spanId
            self.parentSpanId = parentSpanId
        }

        func verbose(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
        func debug(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
        func info(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
        func warning(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
        func error(_: String, error _: (any Error)?, metadata _: [String: String]?) {}

        func withSpan() -> any LoggerProtocol {
            let nextSpan = String(format: "%016llx", UInt64.random(in: 1 ... UInt64.max))
            return FakeLogger(module: module, traceId: traceId, spanId: nextSpan, parentSpanId: spanId)
        }
    }

    func testTraceparentHeaderMatchesW3CSpecification() throws {
        let logger = FakeLogger()
        let provider = D3NexusTraceContextProvider(logger: logger)
        let header = try XCTUnwrap(provider.traceparentHeader())

        let regex = try NSRegularExpression(pattern: "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")
        let range = NSRange(location: 0, length: header.utf16.count)
        XCTAssertEqual(regex.numberOfMatches(in: header, range: range), 1)
    }

    func testConsecutiveCallsGenerateUniqueSpanIdsWithSameTraceId() throws {
        let traceId = "4bf92f3577b34da6a3ce929d0e0e4736"
        let logger = FakeLogger(traceId: traceId)
        let provider = D3NexusTraceContextProvider(logger: logger)

        let header1 = try XCTUnwrap(provider.traceparentHeader())
        let header2 = try XCTUnwrap(provider.traceparentHeader())

        XCTAssertNotEqual(header1, header2)

        let parts1 = header1.split(separator: "-")
        let parts2 = header2.split(separator: "-")

        XCTAssertEqual(parts1.count, 4)
        XCTAssertEqual(parts2.count, 4)

        // Same trace ID
        XCTAssertEqual(parts1[1], parts2[1])
        XCTAssertEqual(String(parts1[1]), traceId)

        // Distinct span IDs
        XCTAssertNotEqual(parts1[2], parts2[2])
    }

    func testDefaultProviderWithLoggingComposition() throws {
        _ = LoggingComposition.buildCoreLogger(subsystem: "com.test.default")
        let provider = D3NexusTraceContextProvider()
        let header = try XCTUnwrap(provider.traceparentHeader())

        let regex = try NSRegularExpression(pattern: "^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")
        let range = NSRange(location: 0, length: header.utf16.count)
        XCTAssertEqual(regex.numberOfMatches(in: header, range: range), 1)
    }
}
