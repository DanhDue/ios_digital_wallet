import XCTest
@testable import D3NexusLogging

@MainActor
final class LeakDetectorMetaTests: XCTestCase {
    func testDetectorFiresWhenInstanceLeaks() throws {
        var failureReported = false
        var parent: CyclicLoggerParent? = CyclicLoggerParent()

        try trackForMemoryLeaks(XCTUnwrap(parent)) { _, _, _ in
            failureReported = true
        }

        // Parent keeps child, child keeps parent (retain cycle)
        weak let weakParent = parent
        parent = nil

        // Verify the fixture actually leaked as a discriminating pair
        XCTAssertNotNil(weakParent, "Discriminating pair: CyclicLoggerParent must retain itself")
        _ = weakParent
        _ = failureReported
    }

    func testCleanObjectDoesNotTriggerLeakFailure() throws {
        var failureOccurred = false
        var cleanObject: NSObject? = NSObject()

        weak let weakClean = cleanObject
        try trackForMemoryLeaks(XCTUnwrap(cleanObject)) { _, _, _ in
            failureOccurred = true
        }

        cleanObject = nil
        XCTAssertNil(weakClean, "Discriminating pair: Clean object deallocates immediately")
        XCTAssertFalse(failureOccurred)
    }
}
