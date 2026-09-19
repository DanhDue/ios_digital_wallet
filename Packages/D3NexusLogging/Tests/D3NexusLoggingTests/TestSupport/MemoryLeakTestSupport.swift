import XCTest

public extension XCTestCase {
    @MainActor
    func trackForMemoryLeaks(
        _ instance: AnyObject,
        failureHandler: (@MainActor (String, StaticString, UInt) -> Void)? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        addTeardownBlock { [weak instance] in
            if instance != nil {
                let description = String(describing: instance)
                let message = "⚠️ Memory Leak Detected: \(description) was not deallocated after test teardown."
                if let failureHandler {
                    failureHandler(message, file, line)
                } else {
                    XCTFail(message, file: file, line: line)
                }
            }
        }
    }
}
