import Core
import XCTest
@testable import Settings

@MainActor
final class UseCaseTests: XCTestCase {
    func testGetSettingsUseCaseForwardsTheRepositoryResult() async {
        let repo = SpySettingsRepository()
        let entity = SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false)
        repo.loadResult = .success(entity)
        let sut = GetSettingsUseCase(repository: repo)

        let viaExecute = await sut.execute()
        let viaCall = await sut()

        XCTAssertEqual(repo.loadCallCount, 2)
        for result in [viaExecute, viaCall] {
            guard case let .success(value) = result else {
                return XCTFail("expected .success")
            }
            XCTAssertEqual(value, entity)
        }
    }

    func testGetSettingsUseCasePropagatesError() async {
        let repo = SpySettingsRepository()
        repo.loadResult = .error(AppError(code: "x", message: "boom"))
        let sut = GetSettingsUseCase(repository: repo)

        let result = await sut.execute()

        guard case let .error(error) = result else {
            return XCTFail("expected .error")
        }
        XCTAssertEqual(error.message, "boom")
    }

    func testSaveSettingsUseCaseForwardsEntityAndResult() async {
        let repo = SpySettingsRepository()
        let sut = SaveSettingsUseCase(repository: repo)
        let entity = SettingsEntity(isDarkMode: false, language: "ja", notificationsEnabled: true)

        _ = await sut.execute(entity)
        _ = await sut(entity)

        XCTAssertEqual(repo.saveCallCount, 2)
        XCTAssertEqual(repo.savedEntities, [entity, entity])
    }

    func testSaveSettingsUseCasePropagatesError() async {
        let repo = SpySettingsRepository()
        repo.saveResult = .error(AppError(code: "x", message: "no disk"))
        let sut = SaveSettingsUseCase(repository: repo)

        let result = await sut.execute(.default)

        guard case let .error(error) = result else {
            return XCTFail("expected .error")
        }
        XCTAssertEqual(error.message, "no disk")
    }

    // MARK: - GetAvailableLanguagesUseCase

    func testGetAvailableLanguagesUseCaseForwardsRepositoryResult() async {
        let repo = SpySettingsRepository()
        let customLangs = [
            AvailableLanguage(languageCode: "de", languageName: "Deutsch", isDefault: false, isActive: true),
        ]
        repo.availableLanguagesResult = .success(customLangs)
        let sut = GetAvailableLanguagesUseCase(repository: repo)

        let result = await sut()

        guard case let .success(langs) = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(langs, customLangs)
    }

    // MARK: - CheckLanguageCachedUseCase

    func testCheckLanguageCachedUseCaseForwardsRepositoryCheck() async {
        let repo = SpySettingsRepository()
        repo.cachedLanguages = ["vi"]
        let sut = CheckLanguageCachedUseCase(repository: repo)

        let isViCached = await sut("vi")
        let isEnCached = await sut("en")

        XCTAssertTrue(isViCached)
        XCTAssertFalse(isEnCached)
    }

    // MARK: - GetDynamicLocalizationUseCase

    func testGetDynamicLocalizationUseCaseSavesOverridesAndAppliesToLocalizationService() async {
        let repo = SpySettingsRepository()
        let service = MockLocalizationService()
        service.currentLanguageCode = "vi"
        repo.localizationOverridesResult = .success(
            TranslationOverride(version: "1.0.1", translations: ["hello": "Xin chào"], checksum: "abc")
        )
        let sut = GetDynamicLocalizationUseCase(repository: repo, localizationService: service)

        let result = await sut("vi")

        guard case .success = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(repo.savedTranslations["vi"], ["hello": "Xin chào"])
        XCTAssertEqual(service.appliedTranslations.count, 1)
        XCTAssertEqual(service.appliedTranslations.first?.languageCode, "vi")
        XCTAssertEqual(service.appliedTranslations.first?.translations["hello"], "Xin chào")
    }

    // MARK: - UpdateUserPreferencesUseCase

    func testUpdateUserPreferencesUseCaseForwardsToRepository() async {
        let repo = SpySettingsRepository()
        let sut = UpdateUserPreferencesUseCase(repository: repo)

        let result = await sut(language: "vi", isDarkMode: true)

        guard case .success = result else {
            return XCTFail("expected .success")
        }
        XCTAssertEqual(repo.updatedPreferences.count, 1)
        XCTAssertEqual(repo.updatedPreferences.first?.language, "vi")
        XCTAssertEqual(repo.updatedPreferences.first?.isDarkMode, true)
    }

    // MARK: - CheckSettingsCachedUseCase

    func testCheckSettingsCachedUseCaseForwardsRepositoryCheck() async {
        let repo = SpySettingsRepository()
        repo.isSettingsCachedResult = true
        let sut = CheckSettingsCachedUseCase(repository: repo)

        let result1 = await sut.execute()
        let result2 = await sut()

        XCTAssertTrue(result1)
        XCTAssertTrue(result2)

        repo.isSettingsCachedResult = false
        let result3 = await sut()
        XCTAssertFalse(result3)
    }
}
