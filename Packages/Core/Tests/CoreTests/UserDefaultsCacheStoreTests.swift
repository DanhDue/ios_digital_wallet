import XCTest
@testable import Core

final class UserDefaultsCacheStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard
    private var spy = SpyLogger()
    private var store = UserDefaultsCacheStore()

    private let keyPrefix = "core.cache."

    override func setUp() {
        super.setUp()
        suiteName = "CoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        spy = SpyLogger()
        store = UserDefaultsCacheStore(defaults: defaults, keyPrefix: keyPrefix, logger: spy)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: round-trip — equivalence partitioning / boundary values

    func testRoundTripsEmptyStringKey() {
        store.set(1, key: "")
        XCTAssertEqual(store.get(Int.self, key: ""), 1)
    }

    func testRoundTripsSingleCharacterKey() {
        store.set(2, key: "k")
        XCTAssertEqual(store.get(Int.self, key: "k"), 2)
    }

    func testRoundTripsVeryLongKey() {
        let longKey = String(repeating: "k", count: 512)
        store.set(3, key: longKey)
        XCTAssertEqual(store.get(Int.self, key: longKey), 3)
    }

    func testRoundTripsIntMinAndIntMax() {
        store.set(Int.min, key: "min")
        store.set(Int.max, key: "max")
        XCTAssertEqual(store.get(Int.self, key: "min"), Int.min)
        XCTAssertEqual(store.get(Int.self, key: "max"), Int.max)
    }

    func testRoundTripsEmptyArray() {
        store.set([Int](), key: "empty")
        XCTAssertEqual(store.get([Int].self, key: "empty"), [])
    }

    func testRoundTripsNestedStruct() {
        let profile = Profile(
            name: "Ada",
            age: 36,
            address: Profile.Address(street: "1 Analytical Ave", zip: 1000),
            tags: ["math", "engine"]
        )
        store.set(profile, key: "profile")
        XCTAssertEqual(store.get(Profile.self, key: "profile"), profile)
    }

    func testRoundTripsOversizedPayload() {
        let big = String(repeating: "A", count: 1_000_000)
        store.set(big, key: "big")
        XCTAssertEqual(store.get(String.self, key: "big"), big)
    }

    // MARK: missing key

    func testGetReturnsNilForMissingKey() {
        XCTAssertNil(store.get(Int.self, key: "absent"))
        XCTAssertTrue(spy.entries.isEmpty, "a plain miss is not an error")
    }

    // MARK: decode failure

    func testGetReturnsNilAndLogsWhenStoredBytesAreWrongType() {
        store.set("hello", key: "k")
        XCTAssertNil(store.get(Int.self, key: "k"))
        XCTAssertEqual(spy.errorEntries.count, 1)
    }

    func testGetReturnsNilAndLogsWhenStoredBytesAreMalformed() {
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: keyPrefix + "corrupt")
        XCTAssertNil(store.get(Profile.self, key: "corrupt"))
        XCTAssertEqual(spy.errorEntries.count, 1)
    }

    // MARK: encode failure

    func testSetWithThrowingEncoderDoesNotCrashLogsAndLeavesKeyUnset() {
        store.set(EncodeExplodes(), key: "boom")
        XCTAssertEqual(spy.errorEntries.count, 1)
        XCTAssertNil(defaults.data(forKey: keyPrefix + "boom"))
    }

    // MARK: remove / clearAll

    func testRemoveDeletesOnlyThatKey() {
        store.set(1, key: "a")
        store.set(2, key: "b")
        store.remove(key: "a")
        XCTAssertNil(store.get(Int.self, key: "a"))
        XCTAssertEqual(store.get(Int.self, key: "b"), 2)
    }

    func testClearAllWipesPrefixedKeysButLeavesForeignKeys() {
        store.set(1, key: "a")
        store.set(2, key: "b")
        defaults.set("keep", forKey: "unrelated.key")

        store.clearAll()

        XCTAssertNil(store.get(Int.self, key: "a"))
        XCTAssertNil(store.get(Int.self, key: "b"))
        XCTAssertEqual(defaults.string(forKey: "unrelated.key"), "keep")
    }
}
