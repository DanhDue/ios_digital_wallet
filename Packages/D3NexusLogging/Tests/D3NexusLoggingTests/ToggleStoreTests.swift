import XCTest
@testable import D3NexusLogging

final class ToggleStoreTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let name = "test.suite.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: name) else {
            fatalError("Could not create test UserDefaults suite")
        }
        return suite
    }

    func testTogglesSurviveRebuild() {
        let suite = makeSuite()
        let store1 = ToggleStore(userDefaults: suite)

        store1.setModuleEnabled("Scanner", enabled: false)
        store1.setAppenderEnabled("pulse", enabled: false)

        XCTAssertFalse(store1.isModuleEnabled("Scanner"))
        XCTAssertFalse(store1.isAppenderEnabled("pulse"))

        let store2 = ToggleStore(userDefaults: suite)
        XCTAssertFalse(store2.isModuleEnabled("Scanner"))
        XCTAssertFalse(store2.isAppenderEnabled("pulse"))
    }

    func testUnknownModuleDefaultsToEnabled() {
        let suite = makeSuite()
        let store = ToggleStore(userDefaults: suite)

        XCTAssertTrue(store.isModuleEnabled("NeverSeen"))
        XCTAssertTrue(store.isAppenderEnabled("oslog"))
    }

    func testCorruptedPersistedDataFallsBackToDefaults() {
        let suite = makeSuite()
        suite.set("NotADictionary", forKey: "logging.module_toggles")
        suite.set(12345, forKey: "logging.appender_toggles")

        let store = ToggleStore(userDefaults: suite)
        XCTAssertTrue(store.isModuleEnabled("AnyModule"))
        XCTAssertTrue(store.isAppenderEnabled("AnyAppender"))
    }

    func testConcurrentToggleOperations() async {
        let suite = makeSuite()
        let store = ToggleStore(userDefaults: suite)

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    let module = "Module_\(index % 5)"
                    store.setModuleEnabled(module, enabled: index.isMultiple(of: 2))
                    _ = store.isModuleEnabled(module)
                }
            }
        }

        XCTAssertTrue(true)
    }
}
