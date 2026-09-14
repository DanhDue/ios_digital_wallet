import XCTest
@testable import Plugin

final class PluginStubTests: XCTestCase {
    func testPluginStubInitializes() {
        let sut = PluginStub()
        XCTAssertEqual(sut.engineVersion, "real-engine")
    }
}
