import XCTest
@testable import Core

/// Coverage for the bare protocol seams `Core` publishes for other packages to
/// implement: `AuthEventSink` and `Logger`.
final class ProtocolSeamsTests: XCTestCase {
    // MARK: AuthEventSink

    private final class SpySink: AuthEventSink, @unchecked Sendable {
        private(set) var unauthorizedCount = 0
        func onUnauthorized() {
            unauthorizedCount += 1
        }
    }

    func testAuthEventSinkForwardsEveryUnauthorizedCall() {
        let sink: any AuthEventSink = SpySink()
        sink.onUnauthorized()
        sink.onUnauthorized()
        XCTAssertEqual((sink as? SpySink)?.unauthorizedCount, 2)
    }

    // MARK: Logger

    func testLoggerSpyRecordsEachLevelIndependently() {
        let spy = SpyLogger()
        spy.debug("d", file: #file, function: #function, line: #line)
        spy.info("i", file: #file, function: #function, line: #line)
        spy.error("e", file: #file, function: #function, line: #line)
        XCTAssertEqual(spy.entries.map(\.level), ["debug", "info", "error"])
        XCTAssertEqual(spy.errorEntries.map(\.message), ["e"])
    }
}
