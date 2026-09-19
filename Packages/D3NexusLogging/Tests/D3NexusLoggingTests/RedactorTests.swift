import XCTest
@testable import D3NexusLogging

final class RedactorTests: XCTestCase {
    private func makeRecord(
        message: String = "Test log",
        metadata: [String: String] = [:],
        errorDescription: String? = nil
    ) -> LogRecord {
        LogRecord(
            module: "Payments",
            level: .info,
            message: message,
            traceId: "4bf92f3577b34da6a3ce929d0e0e4736",
            spanId: "00f067aa0ba902b7",
            errorDescription: errorDescription,
            metadata: metadata
        )
    }

    // UC-8.1: Sensitive headers are masked
    func testSensitiveHeadersMasked() {
        let redactor = Redactor()
        let headers = [
            "Authorization": "Bearer secret_xyz123",
            "Cookie": "session=abc123",
            "X-API-Key": "k-live-9931",
            "Session-Token": "st-7741",
            "User-Agent": "Wallet/1.0",
        ]

        let record = makeRecord(metadata: headers)
        let sanitized = redactor.redact(record)

        XCTAssertEqual(sanitized.metadata["Authorization"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["Cookie"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["X-API-Key"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["Session-Token"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["User-Agent"], "Wallet/1.0")

        // Assert raw values appear nowhere
        for raw in ["secret_xyz123", "abc123", "k-live-9931", "st-7741"] {
            XCTAssertFalse(sanitized.metadata.values.contains(where: { $0.contains(raw) }))
        }
    }

    // UC-8.1: Header matching is case-insensitive
    func testHeaderMatchingIsCaseInsensitive() {
        let redactor = Redactor()
        let headers = [
            "authorization": "Bearer secret_abc",
            "COOKIE": "session=def",
            "x-api-key": "secret_key",
        ]

        let record = makeRecord(metadata: headers)
        let sanitized = redactor.redact(record)

        XCTAssertEqual(sanitized.metadata["authorization"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["COOKIE"], "[REDACTED]")
        XCTAssertEqual(sanitized.metadata["x-api-key"], "[REDACTED]")
    }

    // UC-8.2: Financial and authentication patterns masked inside free text
    func testPatternRedactionCardNumbers() {
        let redactor = Redactor()
        let cardSamples = [
            "4111 1111 1111 1111",
            "4111-1111-1111-1111",
            "4111111111111111",
        ]

        for sample in cardSamples {
            let record = makeRecord(message: "Processing card \(sample) for checkout")
            let sanitized = redactor.redact(record)

            XCTAssertFalse(
                sanitized.message.contains(sample),
                "Raw card number \(sample) must not appear in message"
            )
            XCTAssertTrue(
                sanitized.message.contains("[REDACTED]"),
                "Placeholder must appear in place of \(sample)"
            )
        }
    }

    // UC-8.2: Non-sensitive numbers preserved
    func testNonSensitiveNumbersPreserved() {
        let redactor = Redactor()
        let message = "Order reference 1234 completed with status 200 and quantity 42"
        let record = makeRecord(message: message)
        let sanitized = redactor.redact(record)

        XCTAssertEqual(sanitized.message, message)
        XCTAssertTrue(sanitized.message.contains("1234"))
    }

    // UC-8.2: Redaction applied once at manager boundary across all appenders
    func testManagerBoundaryContainmentWithTwoAppenders() {
        let manager = LogManagerImpl()
        let spy1 = SpyAppender(id: "spy1", respectsModuleToggle: false)
        let spy2 = SpyAppender(id: "spy2", respectsModuleToggle: false)
        manager.registerAppender(spy1)
        manager.registerAppender(spy2)

        let secretToken = "secret_xyz123_token"
        let record = makeRecord(
            message: "User login with Bearer \(secretToken)",
            metadata: ["Authorization": "Bearer \(secretToken)"]
        )

        manager.log(record)

        XCTAssertEqual(spy1.count, 1)
        XCTAssertEqual(spy2.count, 1)

        for spy in [spy1, spy2] {
            let received = spy.records[0]
            XCTAssertFalse(received.message.contains(secretToken))
            XCTAssertFalse(received.metadata.values.contains(where: { $0.contains(secretToken) }))
            XCTAssertEqual(received.metadata["Authorization"], "[REDACTED]")
        }
    }

    // UC-8.3: A record with no sensitive content passes through unchanged
    func testPlainRecordPassesUnchanged() {
        let redactor = Redactor()
        let record = makeRecord(
            message: "Just a standard log event",
            metadata: ["page": "home", "action": "tap"]
        )

        let sanitized = redactor.redact(record)
        XCTAssertEqual(sanitized, record)
    }

    // UC-8.3: Performance budget for 256 KB message with 100 card substrings
    func testPerformanceBudget256KBPayload() {
        let redactor = Redactor()
        let card = "4111 1111 1111 1111"
        var segments: [String] = []

        // Create 256 KB text containing 100 cards
        let padding = String(repeating: "A", count: 2500)
        for index in 0 ..< 100 {
            segments.append("segment_\(index)_\(padding)_card:\(card)")
        }
        let largePayload = segments.joined(separator: "\n")
        XCTAssertGreaterThan(largePayload.utf8.count, 250_000)

        let startTime = CFAbsoluteTimeGetCurrent()
        let sanitizedText = redactor.redact(largePayload)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertFalse(sanitizedText.contains(card))
        // Performance budget: 256 KB redaction must execute well under 100ms (budget <= 50ms)
        XCTAssertLessThan(duration, 0.1, "Redaction took \(duration)s, exceeding 100ms budget")
    }

    /// Edge cases & coverage: errorDescription redaction & custom rules
    func testErrorDescriptionRedacted() {
        let redactor = Redactor()
        let secret = "4111 2222 3333 4444"
        let record = makeRecord(
            message: "Failure occurred",
            errorDescription: "Failed to charge card: \(secret)"
        )

        let sanitized = redactor.redact(record)
        XCTAssertFalse(sanitized.errorDescription?.contains(secret) ?? false)
        XCTAssertTrue(sanitized.errorDescription?.contains("[REDACTED]") ?? false)
    }

    func testCustomRules() {
        let customRule = RedactionRule.pattern(regex: #"api_secret_[a-z0-9]+"#, replacement: "[CUSTOM_REDACTED]")
        let redactor = Redactor(rules: [customRule])

        let sanitized = redactor.redact("Config with api_secret_abc999 enabled")
        XCTAssertEqual(sanitized, "Config with [CUSTOM_REDACTED] enabled")
    }
}
