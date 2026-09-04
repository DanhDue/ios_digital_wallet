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

    // MARK: refresh token — no store

    func testRefreshTokenStartsNilByDefault() {
        XCTAssertNil(SessionManager().refreshToken)
    }

    func testUpdateBothTokensNoStoreReadsBothBack() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        XCTAssertEqual(manager.accessToken, "a")
        XCTAssertEqual(manager.refreshToken, "r")
    }

    func testAccessOnlyConvenienceLeavesRefreshIntactNoStore() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: "a2")
        XCTAssertEqual(manager.accessToken, "a2")
        XCTAssertEqual(manager.refreshToken, "r")
    }

    func testExplicitRefreshNilLeavesRefreshIntactNoStore() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: "a2", refreshToken: nil)
        XCTAssertEqual(manager.refreshToken, "r")
    }

    func testNonNilRefreshRotatesNoStore() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: "a3", refreshToken: "r2")
        XCTAssertEqual(manager.refreshToken, "r2")
    }

    func testClearDropsBothTokensNoStore() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        manager.clear()
        XCTAssertNil(manager.accessToken)
        XCTAssertNil(manager.refreshToken)
    }

    func testEmptyStringAccessTokenIsDistinctFromNil() {
        let manager = SessionManager()
        manager.update(accessToken: "", refreshToken: nil)
        XCTAssertEqual(manager.accessToken, "")
        XCTAssertNotNil(manager.accessToken)
    }

    func testEmptyStringRefreshTokenIsAValueNotAbsence() {
        let manager = SessionManager()
        manager.update(accessToken: "a", refreshToken: "")
        XCTAssertEqual(manager.refreshToken, "")
    }

    func testUpdateBothThroughExistentialProtocol() {
        let manager: any SessionManaging = SessionManager()
        manager.update(accessToken: "a", refreshToken: "r")
        XCTAssertEqual(manager.accessToken, "a")
        XCTAssertEqual(manager.refreshToken, "r")
        manager.clear()
        XCTAssertNil(manager.accessToken)
        XCTAssertNil(manager.refreshToken)
    }

    // MARK: refresh token — with SecureCacheStore

    private static let accessKey = "core.session.access"
    private static let refreshKey = "core.session.refresh"

    private func makeStore() -> SecureCacheStore {
        KeychainCacheStore(backend: InMemoryKeychainBackend())
    }

    func testFreshManagerOverEmptyStoreStartsEmpty() {
        let manager = SessionManager(secureCacheStore: makeStore())
        XCTAssertNil(manager.accessToken)
        XCTAssertNil(manager.refreshToken)
    }

    func testStorePersistsBothTokensAcrossAFreshManager() {
        let store = makeStore()
        SessionManager(secureCacheStore: store).update(accessToken: "a", refreshToken: "r")

        let fresh = SessionManager(secureCacheStore: store)
        XCTAssertEqual(fresh.accessToken, "a")
        XCTAssertEqual(fresh.refreshToken, "r")
    }

    func testStoreKeepsRefreshWhenUpdateRefreshIsNil() {
        let store = makeStore()
        let manager = SessionManager(secureCacheStore: store)
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: "a2", refreshToken: nil)

        let fresh = SessionManager(secureCacheStore: store)
        XCTAssertEqual(fresh.accessToken, "a2")
        XCTAssertEqual(fresh.refreshToken, "r")
    }

    func testStoreRotatesRefreshAndOldValueIsGone() {
        let store = makeStore()
        let manager = SessionManager(secureCacheStore: store)
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: "a3", refreshToken: "r2")

        XCTAssertEqual(store.get(String.self, key: Self.refreshKey), "r2")
        XCTAssertEqual(SessionManager(secureCacheStore: store).refreshToken, "r2")
    }

    func testClearWithStoreRemovesBothKeys() {
        let store = makeStore()
        let manager = SessionManager(secureCacheStore: store)
        manager.update(accessToken: "a", refreshToken: "r")
        manager.clear()

        XCTAssertNil(manager.accessToken)
        XCTAssertNil(manager.refreshToken)
        XCTAssertNil(store.get(String.self, key: Self.accessKey))
        XCTAssertNil(store.get(String.self, key: Self.refreshKey))

        let fresh = SessionManager(secureCacheStore: store)
        XCTAssertNil(fresh.accessToken)
        XCTAssertNil(fresh.refreshToken)
    }

    func testUpdateAccessNilWithStoreRemovesAccessKeyButKeepsRefresh() {
        let store = makeStore()
        let manager = SessionManager(secureCacheStore: store)
        manager.update(accessToken: "a", refreshToken: "r")
        manager.update(accessToken: nil, refreshToken: nil)

        let fresh = SessionManager(secureCacheStore: store)
        XCTAssertNil(fresh.accessToken)
        XCTAssertEqual(fresh.refreshToken, "r")
    }

    func testStoreEmptyStringRefreshTokenPersists() {
        let store = makeStore()
        SessionManager(secureCacheStore: store).update(accessToken: "a", refreshToken: "")
        XCTAssertEqual(SessionManager(secureCacheStore: store).refreshToken, "")
    }

    // MARK: init(accessToken:) + store precedence

    func testExplicitInitAccessTokenWinsOverStoredAndWritesThrough() {
        let store = makeStore()
        store.set("stored", key: Self.accessKey)
        store.set("r0", key: Self.refreshKey)

        let manager = SessionManager(accessToken: "explicit", secureCacheStore: store)
        XCTAssertEqual(manager.accessToken, "explicit")
        XCTAssertEqual(manager.refreshToken, "r0")
        XCTAssertEqual(store.get(String.self, key: Self.accessKey), "explicit")
    }

    func testInitWithoutExplicitAccessTokenLoadsStoredValue() {
        let store = makeStore()
        store.set("stored", key: Self.accessKey)
        store.set("r0", key: Self.refreshKey)

        let manager = SessionManager(secureCacheStore: store)
        XCTAssertEqual(manager.accessToken, "stored")
        XCTAssertEqual(manager.refreshToken, "r0")
    }

    // MARK: concurrency safety — with store

    func testConcurrentUpdatesAndReadsWithStoreDoNotCrash() async {
        let manager = SessionManager(secureCacheStore: makeStore())
        manager.update(accessToken: "seed", refreshToken: "seed-r")
        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask { manager.update(accessToken: "t\(index)", refreshToken: "r\(index)") }
                group.addTask { _ = manager.accessToken }
                group.addTask { _ = manager.refreshToken }
            }
        }
        XCTAssertNotNil(manager.accessToken)
        XCTAssertNotNil(manager.refreshToken)
    }
}
