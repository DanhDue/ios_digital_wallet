import Core
import XCTest
@testable import Settings

@MainActor
final class SettingsRepositoryImplTests: XCTestCase {
    @MainActor
    private struct Fixture {
        let sut: SettingsRepositoryImpl
        let cache: InMemoryCacheStore
        let logger: SpyLogger

        init() {
            logger = SpyLogger()
            cache = InMemoryCacheStore(logger: logger)
            sut = SettingsRepositoryImpl(cache: cache, logger: logger)
        }
    }

    func testSaveThenLoadRoundTripsThroughTheCache() async {
        let fixture = Fixture()
        let entity = SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false)

        _ = await fixture.sut.save(entity)
        let loaded = await fixture.sut.load()

        guard case let .success(result) = loaded else {
            return XCTFail("expected .success, got \(loaded)")
        }
        XCTAssertEqual(result, entity)
    }

    func testSaveWritesUnderTheSharedSettingsKey() async {
        let fixture = Fixture()

        _ = await fixture.sut.save(.default)

        XCTAssertTrue(fixture.cache.contains(key: "settings"))
    }

    func testLoadWithMissingKeyReturnsDefaultAndLogsInfoNotError() async {
        let fixture = Fixture()

        let loaded = await fixture.sut.load()

        guard case let .success(result) = loaded else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(result, .default)
        XCTAssertTrue(fixture.logger.errorMessages.isEmpty)
        XCTAssertFalse(fixture.logger.infoMessages.isEmpty, "the fallback-to-default is logged at .info")
    }

    func testLoadWithCorruptBytesReturnsDefaultAndCacheLogsError() async {
        let fixture = Fixture()
        fixture.cache.seedRaw(Data("💥 not json".utf8), key: "settings")

        let loaded = await fixture.sut.load()

        guard case let .success(result) = loaded else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(result, .default)
        XCTAssertFalse(fixture.logger.errorMessages.isEmpty, "the decode failure is logged at .error by the cache")
    }

    func testSaveAlwaysReportsSuccessForTheLocalCache() async {
        let fixture = Fixture()

        let result = await fixture.sut.save(.default)

        guard case .success = result else {
            return XCTFail("local cache save cannot fail")
        }
    }
}
