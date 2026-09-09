import Core
import Factory
import Framework
import Platform
import XCTest
@testable import Settings

@MainActor
final class SettingsViewModelDITests: XCTestCase {
    func testProductionInitializationResolvesDependenciesAndChangesLanguage() async {
        let sut = SettingsViewModel()
        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "content" }

        sut.dispatch(.selectLanguage("vi"))
        await poll { sut.uiState.settings.language == "vi" }

        XCTAssertEqual(sut.uiState.settings.language, "vi")
    }

    func testDesignatedInitWithDirectUseCasesLoadsAndSavesWithoutRepository() async {
        let repo = SpySettingsRepository()
        let getSettings = GetSettingsUseCase(repository: repo)
        let saveSettings = SaveSettingsUseCase(repository: repo)
        let getAvailableLangs = GetAvailableLanguagesUseCase(repository: repo)
        let checkCached = CheckLanguageCachedUseCase(repository: repo)
        let loc = MockLocalizationService()
        let changeLang = ChangeLanguageUseCase(
            checkLanguageCachedUseCase: checkCached,
            getDynamicLocalizationUseCase: GetDynamicLocalizationUseCase(repository: repo, localizationService: loc),
            updateUserPreferencesUseCase: UpdateUserPreferencesUseCase(repository: repo),
            localizationService: loc
        )

        let sut = SettingsViewModel(
            getSettings: getSettings,
            saveSettings: saveSettings,
            getAvailableLanguages: getAvailableLangs,
            checkLanguageCached: checkCached,
            changeLanguage: changeLang
        )

        sut.dispatch(.onAppear)
        await poll { sut.viewState.tag == "content" }
        XCTAssertEqual(sut.viewState.tag, "content")
        XCTAssertEqual(repo.loadCallCount, 1)

        sut.dispatch(.toggleNotifications)
        await poll { sut.uiState.isSaving == false }
        XCTAssertEqual(repo.saveCallCount, 1)
    }
}
