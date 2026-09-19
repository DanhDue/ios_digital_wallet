import Logging
import os
import XCTest
@testable import D3NexusLogging

final class SwiftLogBridgeTests: XCTestCase {
    private final class SpyManager: LogManager, @unchecked Sendable {
        private let storage = OSAllocatedUnfairLock<[LogRecord]>(initialState: [])

        var records: [LogRecord] {
            storage.withLock { $0 }
        }

        func log(_ record: LogRecord) {
            storage.withLock { $0.append(record) }
        }

        func getLogger(module: String) -> any LoggerProtocol {
            NoOpLogger(module: module)
        }

        func registerAppender(_: any LogAppender) {}
        func setModuleEnabled(_: String, enabled _: Bool) {}
        func isModuleEnabled(_: String) -> Bool {
            true
        }

        func setAppenderEnabled(_: String, enabled _: Bool) {}
        func isAppenderEnabled(_: String) -> Bool {
            true
        }
    }

    // Scenario: swift-log levels collapse onto LogLevel as documented
    func testSwiftLogLevelMapping() {
        let cases: [(Logging.Logger.Level, LogLevel)] = [
            (.trace, .verbose),
            (.debug, .debug),
            (.info, .info),
            (.notice, .info),
            (.warning, .warning),
            (.error, .error),
            (.critical, .error),
        ]

        for (swiftLevel, expectedMappedLevel) in cases {
            let spy = SpyManager()
            var handler = D3NexusLogHandler(label: "TestModule", manager: spy)
            handler.logLevel = .trace

            handler.log(
                level: swiftLevel,
                message: "Test message for \(swiftLevel)",
                metadata: .none,
                source: "UnitTest",
                file: #file,
                function: #function,
                line: #line
            )

            XCTAssertEqual(spy.records.count, 1)
            XCTAssertEqual(
                spy.records[0].level,
                expectedMappedLevel,
                "Level \(swiftLevel) should map to \(expectedMappedLevel)"
            )
        }
    }

    // Scenario: Existing trace identifiers in metadata are honoured rather than regenerated
    func testExistingTraceAndSpanHonoured() {
        let spy = SpyManager()
        let handler = D3NexusLogHandler(label: "Auth", manager: spy)
        let traceId = "4bf92f3577b34da6a3ce929d0e0e4736"
        let spanId = "00f067aa0ba902b7"
        let parentSpanId = "11a067aa0ba902c8"

        handler.log(
            level: .info,
            message: "Span context test",
            metadata: [
                "traceId": .string(traceId),
                "spanId": .string(spanId),
                "parentSpanId": .string(parentSpanId),
            ],
            source: "UnitTest",
            file: #file,
            function: #function,
            line: #line
        )

        XCTAssertEqual(spy.records.count, 1)
        let record = spy.records[0]
        XCTAssertEqual(record.traceId, traceId)
        XCTAssertEqual(record.spanId, spanId)
        XCTAssertEqual(record.parentSpanId, parentSpanId)
    }

    // Scenario: An event without trace metadata receives freshly generated, well-formed identifiers
    func testMissingTraceMetadataGeneratesFreshHexIdentifiers() {
        let spy = SpyManager()
        let handler = D3NexusLogHandler(label: "Database", manager: spy)

        handler.log(
            level: .info,
            message: "Generating identifiers",
            metadata: .none,
            source: "UnitTest",
            file: #file,
            function: #function,
            line: #line
        )

        XCTAssertEqual(spy.records.count, 1)
        let record = spy.records[0]
        XCTAssertEqual(record.traceId.count, 32)
        XCTAssertEqual(record.spanId.count, 16)

        let hexCharset = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertTrue(record.traceId.unicodeScalars.allSatisfy { hexCharset.contains($0) })
        XCTAssertTrue(record.spanId.unicodeScalars.allSatisfy { hexCharset.contains($0) })
    }

    // Scenario: The label becomes the record module and per-handler metadata is preserved
    func testLabelTranslatesToRecordModuleAndMetadataPreserved() {
        let spy = SpyManager()
        var handler = D3NexusLogHandler(label: "ThirdPartyLib", manager: spy)
        handler[metadataKey: "env"] = .string("staging")

        handler.log(
            level: .info,
            message: "Library initialized",
            metadata: ["component": .string("cache")],
            source: "UnitTest",
            file: #file,
            function: #function,
            line: #line
        )

        XCTAssertEqual(spy.records.count, 1)
        let record = spy.records[0]
        XCTAssertEqual(record.module, "ThirdPartyLib")
        XCTAssertEqual(record.metadata["env"], "staging")
        XCTAssertEqual(record.metadata["component"], "cache")
        XCTAssertEqual(handler[metadataKey: "env"], .string("staging"))
    }

    func testLogEventDispatchesToManager() {
        let spy = SpyManager()
        let handler = D3NexusLogHandler(label: "EventLogger", manager: spy)
        let event = Logging.LogEvent(
            level: .warning,
            message: "Warning event",
            metadata: ["tag": .string("audit")],
            source: "AuthSystem",
            file: #file,
            function: #function,
            line: #line
        )

        handler.log(event: event)

        XCTAssertEqual(spy.records.count, 1)
        XCTAssertEqual(spy.records[0].module, "EventLogger")
        XCTAssertEqual(spy.records[0].level, .warning)
        XCTAssertEqual(spy.records[0].message, "Warning event")
        XCTAssertEqual(spy.records[0].metadata["tag"], "audit")
    }
}
