import XCTest
@testable import Core

final class SessionManagerTests: XCTestCase {
    // MARK: initial state

    func testStartsEmptyByDefault() {
        XCTAssertNil(SessionManager().accessToken)
    }

    func testHonoursInitialToken() {
        XCTAssertEqual(SessionManager(accessToken: "seed").accessToken, "seed")
    }

    // MARK: state transitions

    func testUpdateThenReadReturnsNewToken() {
        let manager = SessionManager()
        manager.update(accessToken: "abc")
        XCTAssertEqual(manager.accessToken, "abc")
    }

    func testUpdateThenClearLeavesTokenNil() {
        let manager = SessionManager(accessToken: "abc")
        manager.clear()
        XCTAssertNil(manager.accessToken)
    }

    func testUpdateToNilClearsToken() {
        let manager = SessionManager(accessToken: "abc")
        manager.update(accessToken: nil)
        XCTAssertNil(manager.accessToken)
    }

    func testClearWhenAlreadyEmptyIsANoOp() {
        let manager = SessionManager()
        manager.clear()
        manager.clear()
        XCTAssertNil(manager.accessToken)
    }

    func testOverwriteReplacesPreviousToken() {
        let manager = SessionManager(accessToken: "first")
        manager.update(accessToken: "second")
        XCTAssertEqual(manager.accessToken, "second")
    }

    // MARK: protocol usage

    func testUsableThroughExistentialProtocol() {
        let manager: any SessionManaging = SessionManager()
        manager.update(accessToken: "v")
        XCTAssertEqual(manager.accessToken, "v")
        manager.clear()
        XCTAssertNil(manager.accessToken)
    }

    // MARK: concurrency safety

    func testConcurrentUpdatesAndReadsDoNotCrash() async {
        let manager = SessionManager()
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask { manager.update(accessToken: "t\(index)") }
                group.addTask { _ = manager.accessToken }
            }
        }
        XCTAssertNotNil(manager.accessToken)
    }
}
