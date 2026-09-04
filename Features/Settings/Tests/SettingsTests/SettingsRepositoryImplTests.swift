import Core
import Network
import XCTest
@testable import Settings

@MainActor
final class SettingsRepositoryImplTests: XCTestCase {
    @MainActor
    private struct Fixture {
        let sut: SettingsRepositoryImpl
        let cache: InMemoryCacheStore
        let apiClient: MockAPIClient
        let logger: SpyLogger

        init(hasClient: Bool = true) {
            logger = SpyLogger()
            cache = InMemoryCacheStore(logger: logger)
            apiClient = MockAPIClient()
            sut = SettingsRepositoryImpl(
                cache: cache,
                apiClient: hasClient ? apiClient : nil,
                logger: logger
            )
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

    // MARK: - Available Languages

    func testGetAvailableLanguagesFromRemoteSuccess() async {
        let fixture = Fixture()
        let languages = [
            AvailableLanguageDTO(languageCode: "en", languageName: "English", isDefault: true, isActive: true),
            AvailableLanguageDTO(languageCode: "vi", languageName: "Tiếng Việt", isDefault: false, isActive: true),
        ]
        let wrapped = BaseResponseObject<BootstrapDataDTO>(
            data: BootstrapDataDTO(availableLanguages: languages),
            message: "OK"
        )
        fixture.apiClient.enqueueSuccess(wrapped)

        let result = await fixture.sut.getAvailableLanguages()

        guard case let .success(langs) = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(langs.count, 2)
        XCTAssertEqual(langs[0].languageCode, "en")
        XCTAssertEqual(langs[1].languageCode, "vi")
    }

    func testGetAvailableLanguagesFallsBackToCachedWhenRemoteFails() async {
        let fixture = Fixture()
        fixture.apiClient.enqueueError(NetworkError.server(500))

        let cached = [
            AvailableLanguageDTO(languageCode: "fr", languageName: "Français", isDefault: false, isActive: true),
        ]
        fixture.cache.set(cached, key: SettingsLocalDataSource.availableLanguagesKey)

        let result = await fixture.sut.getAvailableLanguages()

        guard case let .success(langs) = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(langs.count, 1)
        XCTAssertEqual(langs[0].languageCode, "fr")
    }

    func testGetAvailableLanguagesFallsBackToDefaultsWhenNoCacheAndNoRemote() async {
        let fixture = Fixture(hasClient: false)

        let result = await fixture.sut.getAvailableLanguages()

        guard case let .success(langs) = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(langs, AvailableLanguage.defaultLanguages)
    }

    // MARK: - Language Cached Check

    func testIsLanguageCachedReturnsTrueWhenPresent() async {
        let fixture = Fixture()
        let initialCached = await fixture.sut.isLanguageCached("vi")
        XCTAssertFalse(initialCached)

        fixture.cache.set(["app.title": "Ví Điện Tử"], key: SettingsLocalDataSource.translationKey(for: "vi"))
        let isCached = await fixture.sut.isLanguageCached("vi")
        XCTAssertTrue(isCached)
    }

    // MARK: - Localization Overrides

    func testGetLocalizationOverridesSuccess() async {
        let fixture = Fixture()
        let overrideDTO = TranslationOverrideDTO(version: "1.2.0", translations: ["settings.title": "Cài đặt"])
        let wrapped = BaseResponseObject<TranslationOverrideDTO>(data: overrideDTO, message: "OK")
        fixture.apiClient.enqueueSuccess(wrapped)

        let result = await fixture.sut.getLocalizationOverrides(code: "vi", sinceVersion: "1.0.0", eTag: "W/\"123\"")

        guard case let .success(override) = result, let unwrapped = override else {
            return XCTFail("expected .success with override")
        }
        XCTAssertEqual(unwrapped.version, "1.2.0")
        XCTAssertEqual(unwrapped.translations["settings.title"], "Cài đặt")
    }

    func testGetLocalizationOverridesHandles304NotModified() async {
        let fixture = Fixture()
        fixture.apiClient.enqueueError(NetworkError.client(304))

        let result = await fixture.sut.getLocalizationOverrides(code: "vi", sinceVersion: "1.0.0", eTag: "W/\"123\"")

        guard case let .success(override) = result else {
            return XCTFail("expected .success")
        }
        XCTAssertNil(override)
    }

    // MARK: - Save Cached Translations

    func testSaveCachedTranslationsWritesToCache() async {
        let fixture = Fixture()

        let result = await fixture.sut.saveCachedTranslations(
            code: "vi",
            version: "2.0.0",
            eTag: "etag-abc",
            translations: ["greeting": "Xin chào"]
        )

        guard case .success = result else {
            return XCTFail("expected .success")
        }
        let isCached = await fixture.sut.isLanguageCached("vi")
        XCTAssertTrue(isCached)
        XCTAssertEqual(fixture.cache.get(String.self, key: SettingsLocalDataSource.versionKey(for: "vi")), "2.0.0")
        XCTAssertEqual(fixture.cache.get(String.self, key: SettingsLocalDataSource.eTagKey(for: "vi")), "etag-abc")
    }

    // MARK: - Update User Preferences

    func testUpdateUserPreferencesSuccess() async {
        let fixture = Fixture()
        fixture.apiClient.enqueueSuccess(EmptyResponse())

        let result = await fixture.sut.updateUserPreferences(language: "vi", isDarkMode: true)

        guard case .success = result else {
            return XCTFail("expected .success")
        }
    }
}
