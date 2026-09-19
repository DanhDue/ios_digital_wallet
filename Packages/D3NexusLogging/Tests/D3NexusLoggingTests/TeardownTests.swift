import XCTest
@testable import D3NexusLogging

final class TeardownTests: XCTestCase {
    func testCleanObjectTeardownPattern() {
        weak var weakInstance: NSObject?
        do {
            let instance = NSObject()
            weakInstance = instance
            XCTAssertNotNil(weakInstance)
        }
        XCTAssertNil(weakInstance, "Expected object to deallocate upon leaving scope")
    }
}
