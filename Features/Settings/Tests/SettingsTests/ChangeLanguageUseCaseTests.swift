import Core
import XCTest
@testable import Settings

@MainActor
final class ChangeLanguageUseCaseTests: XCTestCase {
    @MainActor
    private struct Fixture {
        let repo: SpySettingsRepository
        let localizationService: MockLocalizationService
        let sut: ChangeLanguageUseCase

        init() {
            repo = SpySettingsRepository()
            localizationService = MockLocalizationService()
            localizationService.currentLanguageCode = "en"

            let checkCached = CheckLanguageCachedUseCase(repository: repo)
            let getDynamic = GetDynamicLocalizationUseCase(
                repository: repo,
                localizationService: localizationService
            )
            let updatePref = UpdateUserPreferencesUseCase(repository: repo)

            sut = ChangeLanguageUseCase(
                checkLanguageCachedUseCase: checkCached,
                getDynamicLocalizationUseCase: getDynamic,
                updateUserPreferencesUseCase: updatePref,
                localizationService: localizationService
            )
        }
    }

    private func collectEmissions(from stream: AsyncStream<LanguageSyncStatus>) async -> [LanguageSyncStatus] {
        var results: [LanguageSyncStatus] = []
        for await status in stream {
            results.append(status)
        }
        return results
    }

    func testScenario1_HappyPath_SwitchingToCachedLanguage() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = ["ja"]

        let stream = fixture.sut("ja")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.cachedApplied, .success])
        XCTAssertEqual(fixture.localizationService.setLocaleCalls, ["ja"])
        XCTAssertEqual(fixture.repo.updatedPreferences.count, 1)
        XCTAssertEqual(fixture.repo.updatedPreferences.first?.language, "ja")
    }

    func testScenario2_HappyPath_SwitchingToUncachedLanguage() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = []
        let stream = fixture.sut("fr")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.loading, .success])
        XCTAssertEqual(fixture.localizationService.setLocaleCalls, ["fr"])
        XCTAssertEqual(fixture.repo.updatedPreferences.count, 1)
        XCTAssertEqual(fixture.repo.updatedPreferences.first?.language, "fr")
    }

    func testScenario2b_SwitchingToUncachedJapaneseEmitsLoadingAndSuccess() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = []
        let stream = fixture.sut("ja")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.loading, .success])
        XCTAssertEqual(fixture.localizationService.setLocaleCalls, ["ja"])
        XCTAssertEqual(fixture.repo.updatedPreferences.first?.language, "ja")
    }

    func testScenario2c_SwitchingToUncachedKoreanEmitsLoadingAndSuccess() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = []
        let stream = fixture.sut("ko")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.loading, .success])
        XCTAssertEqual(fixture.localizationService.setLocaleCalls, ["ko"])
        XCTAssertEqual(fixture.repo.updatedPreferences.first?.language, "ko")
    }

    func testScenario3_EdgeCase_SwitchingToSameLanguageNoOp() async {
        let fixture = Fixture()
        fixture.localizationService.currentLanguageCode = "en"

        let stream = fixture.sut("en")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [])
        XCTAssertTrue(fixture.localizationService.setLocaleCalls.isEmpty)
        XCTAssertTrue(fixture.repo.updatedPreferences.isEmpty)
    }

    func testScenario4_EdgeCase_SwitchingToSameLanguageWithNetworkFailure() async {
        let fixture = Fixture()
        fixture.localizationService.currentLanguageCode = "en"
        fixture.repo.localizationOverridesResult = .error(AppError(code: "net", message: "offline"))

        let stream = fixture.sut("en")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.error(AppError(code: "net", message: "offline"))])
        XCTAssertTrue(fixture.localizationService.setLocaleCalls.isEmpty)
        XCTAssertTrue(fixture.repo.updatedPreferences.isEmpty)
    }

    func testScenario5_NetworkFailure_SwitchingToUncachedLanguageFails() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = []
        fixture.repo.localizationOverridesResult = .error(AppError(code: "net", message: "timeout"))

        let stream = fixture.sut("fr")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.loading, .error(AppError(code: "net", message: "timeout"))])
        XCTAssertTrue(
            fixture.localizationService.setLocaleCalls.isEmpty,
            "Uncached language should not set locale on network failure"
        )
        XCTAssertEqual(fixture.localizationService.currentLanguageCode, "en")
    }

    func testScenario6_NetworkFailure_SwitchingToCachedLanguageAppliesOptimistic() async {
        let fixture = Fixture()
        fixture.repo.cachedLanguages = ["ja"]
        fixture.repo.localizationOverridesResult = .error(AppError(code: "net", message: "server 500"))

        let stream = fixture.sut("ja")
        let emissions = await collectEmissions(from: stream)

        XCTAssertEqual(emissions, [.cachedApplied, .error(AppError(code: "net", message: "server 500"))])
        XCTAssertEqual(fixture.localizationService.setLocaleCalls, ["ja"])
        XCTAssertEqual(fixture.repo.updatedPreferences.count, 1)
        XCTAssertEqual(fixture.repo.updatedPreferences.first?.language, "ja")
    }
}
