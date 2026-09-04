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
}
