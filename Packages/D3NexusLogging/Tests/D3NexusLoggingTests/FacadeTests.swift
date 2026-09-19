import XCTest
@testable import D3NexusLogging

final class FacadeTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let name = "test.suite.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else {
            fatalError("Could not create test UserDefaults suite")
        }
        return suite
    }

    override func setUp() {
        super.setUp()
        D3NexusLogger.resetForTesting()
    }

    override func tearDown() {
        D3NexusLogger.resetForTesting()
        super.tearDown()
    }

    func testUninitializedFacadeReturnsNoOpLogger() {
        let logger = D3NexusLogger.getLogger("Uninitialized")
        XCTAssertTrue(logger is NoOpLogger)

        // Safe to call, no crashes
        logger.debug("Should be discarded")
        logger.info("Should be discarded")
        logger.warning("Should be discarded")
        logger.error("Should be discarded")
        logger.verbose("Should be discarded")
        let child = logger.withSpan()
        XCTAssertTrue(child is NoOpLogger)
    }

    func testInitializedFacadeDispatchesToManager() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        let spy = SpyAppender(id: "spy", respectsModuleToggle: false)
        manager.registerAppender(spy)

        D3NexusLogger.initialize(manager: manager)

        let logger = D3NexusLogger.getLogger("Settings")
        XCTAssertFalse(logger is NoOpLogger)

        logger.info("Facade test")
        XCTAssertEqual(spy.count, 1)
        XCTAssertEqual(spy.records[0].message, "Facade test")
    }

    func testFacadeToggleForwarding() {
        let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite()))
        D3NexusLogger.initialize(manager: manager)

        D3NexusLogger.setModuleEnabled("Payments", enabled: false)
        XCTAssertFalse(D3NexusLogger.isModuleEnabled("Payments"))

        D3NexusLogger.setAppenderEnabled("pulse", enabled: false)
        XCTAssertFalse(D3NexusLogger.isAppenderEnabled("pulse"))
    }
}
