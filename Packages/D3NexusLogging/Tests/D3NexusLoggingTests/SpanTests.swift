import os
import XCTest
@testable import D3NexusLogging

final class SpanTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let name = "test.suite.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else {
            fatalError("Could not create test UserDefaults suite")
        }
        return suite
    }

    func testChildPreservesTraceAndLinksParentSpan() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let spy = SpyAppender(id: "spy", respectsModuleToggle: false)
        manager.registerAppender(spy)

        let root = manager.getLogger(module: "Settings")
        let child = root.withSpan()

        XCTAssertEqual(child.traceId, root.traceId)
        XCTAssertNotEqual(child.spanId, root.spanId)
        XCTAssertEqual(child.parentSpanId, root.spanId)

        child.debug("Child operation")

        XCTAssertEqual(spy.count, 1)
        let record = spy.records[0]
        XCTAssertEqual(record.traceId, root.traceId)
        XCTAssertEqual(record.spanId, child.spanId)
        XCTAssertEqual(record.parentSpanId, root.spanId)
    }

    func testThreeLevelLineage() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let root = manager.getLogger(module: "UseCase")
        let child = root.withSpan()
        let grandchild = child.withSpan()

        XCTAssertEqual(root.traceId, child.traceId)
        XCTAssertEqual(child.traceId, grandchild.traceId)

        XCTAssertEqual(grandchild.parentSpanId, child.spanId)
        XCTAssertEqual(child.parentSpanId, root.spanId)
        XCTAssertNil(root.parentSpanId)
    }

    @MainActor
    func testChildDoesNotRetainParent() throws {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let spy = SpyAppender(id: "spy", respectsModuleToggle: false)
        manager.registerAppender(spy)

        var parent: (any LoggerProtocol)? = manager.getLogger(module: "Parent")
        let child = try XCTUnwrap(parent?.withSpan())

        try trackForMemoryLeaks(XCTUnwrap(parent) as AnyObject)
        weak let weakParent = parent as AnyObject?
        parent = nil

        XCTAssertNil(weakParent, "Parent logger must deallocate when reference is dropped")

        child.info("Child still logs after parent deallocated")
        XCTAssertEqual(spy.count, 1)
        XCTAssertEqual(spy.records[0].message, "Child still logs after parent deallocated")
    }

    func testConcurrentSpanCreationGeneratesDistinctIdentifiers() async {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let root = manager.getLogger(module: "Concurrent")

        let count = 500
        let spanIds = await withTaskGroup(of: String.self) { group in
            for _ in 0 ..< count {
                group.addTask {
                    let child = root.withSpan()
                    return child.spanId
                }
            }

            var results = [String]()
            for await spanId in group {
                results.append(spanId)
            }
            return results
        }

        XCTAssertEqual(spanIds.count, count)
        let uniqueSpans = Set(spanIds)
        XCTAssertEqual(uniqueSpans.count, count, "All 500 spanIds must be unique")
    }

    func testAllSeveritiesMapCorrectly() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let spy = SpyAppender(id: "spy", respectsModuleToggle: false)
        manager.registerAppender(spy)

        let logger = manager.getLogger(module: "Core")
        logger.verbose("Verbose msg")
        logger.debug("Debug msg")
        logger.info("Info msg")
        logger.warning("Warning msg")
        logger.error("Error msg")

        XCTAssertEqual(spy.count, 5)
        XCTAssertEqual(spy.records[0].level, .verbose)
        XCTAssertEqual(spy.records[1].level, .debug)
        XCTAssertEqual(spy.records[2].level, .info)
        XCTAssertEqual(spy.records[3].level, .warning)
        XCTAssertEqual(spy.records[4].level, .error)
    }
}
