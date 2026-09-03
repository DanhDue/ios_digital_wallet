import XCTest
@testable import Core

final class KeychainCacheStoreTests: XCTestCase {
    private var backend = InMemoryKeychainBackend()
    private var spy = SpyLogger()
    private var store = KeychainCacheStore(backend: InMemoryKeychainBackend())

    override func setUp() {
        super.setUp()
        backend = InMemoryKeychainBackend()
        spy = SpyLogger()
        store = KeychainCacheStore(backend: backend, logger: spy)
    }

    // MARK: round-trip

    func testRoundTripsCodableValueThroughTheBackend() {
        let profile = Profile(
            name: "Grace",
            age: 40,
            address: Profile.Address(street: "9 Compiler Ct", zip: 2000),
            tags: ["navy", "cobol"]
        )
        store.set(profile, key: "profile")
        XCTAssertEqual(store.get(Profile.self, key: "profile"), profile)
    }

    func testRoundTripsBoundaryIntegers() {
        store.set(Int.min, key: "min")
        store.set(Int.max, key: "max")
        XCTAssertEqual(store.get(Int.self, key: "min"), Int.min)
        XCTAssertEqual(store.get(Int.self, key: "max"), Int.max)
    }

    // MARK: absent item

    func testGetReturnsNilWhenItemAbsentWithoutThrowingOrLogging() {
        XCTAssertNil(store.get(Int.self, key: "nope"))
        XCTAssertTrue(spy.entries.isEmpty)
    }

    // MARK: decode / encode failure

    func testGetReturnsNilAndLogsWhenStoredBytesDoNotDecode() {
        store.set("string-value", key: "k")
        XCTAssertNil(store.get(Int.self, key: "k"))
        XCTAssertEqual(spy.errorEntries.count, 1)
    }

    func testSetWithThrowingEncoderLogsAndLeavesKeyUnset() {
        store.set(EncodeExplodes(), key: "boom")
        XCTAssertEqual(spy.errorEntries.count, 1)
        XCTAssertNil(store.get(EncodeExplodes.self, key: "boom"))
    }

    // MARK: remove / clearAll

    func testRemoveDeletesOnlyThatKey() {
        store.set(1, key: "a")
        store.set(2, key: "b")
        store.remove(key: "a")
        XCTAssertNil(store.get(Int.self, key: "a"))
        XCTAssertEqual(store.get(Int.self, key: "b"), 2)
    }

    func testClearAllWipesEveryKey() {
        store.set(1, key: "a")
        store.set(2, key: "b")
        store.clearAll()
        XCTAssertNil(store.get(Int.self, key: "a"))
        XCTAssertNil(store.get(Int.self, key: "b"))
        XCTAssertTrue(backend.storage.isEmpty)
    }

    // MARK: live Keychain smoke (opt-in — never runs in headless CI)

    func testLiveKeychainRoundTripBestEffort() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CORE_KEYCHAIN_SMOKE"] == "1",
            "Set CORE_KEYCHAIN_SMOKE=1 to exercise the real system Keychain"
        )
        let live = KeychainCacheStore(service: "com.core.securecache.tests.\(UUID().uuidString)")
        live.set("token", key: "session")
        XCTAssertEqual(live.get(String.self, key: "session"), "token")
        live.clearAll()
        XCTAssertNil(live.get(String.self, key: "session"))
    }
}
