import XCTest
@testable import D3NexusLogging

final class TraceIdentifierTests: XCTestCase {
    func testTraceIdFormat() throws {
        let traceId = TraceIdentifier.newTraceId()
        let regex = try NSRegularExpression(pattern: "^[0-9a-f]{32}$")
        let range = NSRange(location: 0, length: traceId.utf16.count)
        XCTAssertEqual(
            regex.numberOfMatches(in: traceId, range: range),
            1,
            "TraceId must be 32 lowercase hex characters"
        )
    }

    func testSpanIdFormat() throws {
        let spanId = TraceIdentifier.newSpanId()
        let regex = try NSRegularExpression(pattern: "^[0-9a-f]{16}$")
        let range = NSRange(location: 0, length: spanId.utf16.count)
        XCTAssertEqual(regex.numberOfMatches(in: spanId, range: range), 1, "SpanId must be 16 lowercase hex characters")
    }

    func testTenThousandSpanIdsAreDistinctAndWellFormed() throws {
        var generated = Set<String>()
        let regex = try NSRegularExpression(pattern: "^[0-9a-f]{16}$")

        for _ in 0 ..< 10000 {
            let spanId = TraceIdentifier.newSpanId()
            let range = NSRange(location: 0, length: spanId.utf16.count)
            XCTAssertEqual(regex.numberOfMatches(in: spanId, range: range), 1)
            generated.insert(spanId)
        }

        XCTAssertEqual(generated.count, 10000, "All 10,000 spanIds generated must be unique")
    }
}
