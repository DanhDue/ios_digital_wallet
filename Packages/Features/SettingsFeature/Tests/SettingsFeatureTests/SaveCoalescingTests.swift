import Core
import XCTest
@testable import SettingsFeature

/// The shared `"save"` / `"load"` effect keys coalesce a burst of dispatches
/// into a single use-case call for the final value (Source Spec §5.5).
@MainActor
final class SaveCoalescingTests: XCTestCase {
    func testThreeRapidToggleDarkModeRunOnlyOneSaveForTheLastValue() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        let gate = AsyncGate()
        env.repo.saveGate = gate

        // Three toggles inside one runloop turn: dark mode false -> true -> false -> true.
        env.sut.dispatch(.toggleDarkMode)
        env.sut.dispatch(.toggleDarkMode)
        env.sut.dispatch(.toggleDarkMode)

        // Let the surviving effect reach the (gated) save call.
        await poll { env.repo.saveCallCount >= 1 }
        await settle()
        await gate.open()
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(env.repo.saveCallCount, 1, "prior same-key effects are cancelled before they call the use case")
        XCTAssertEqual(env.repo.savedEntities.count, 1)
        XCTAssertEqual(env.repo.savedEntities.last?.isDarkMode, true, "the persisted value is the last toggle")
        XCTAssertEqual(env.sut.uiState.settings.isDarkMode, true)
    }

    func testMixedRapidActionsCoalesceToTheLastMutation() async {
        let env = SettingsEnv()
        env.repo.loadResult = .success(.default)
        env.sut.dispatch(.onAppear)
        await poll { env.sut.viewState.tag == "content" }

        let gate = AsyncGate()
        env.repo.saveGate = gate

        env.sut.dispatch(.toggleDarkMode)
        env.sut.dispatch(.selectLanguage("vi"))
        env.sut.dispatch(.toggleNotifications)

        await poll { env.repo.saveCallCount >= 1 }
        await settle()
        await gate.open()
        await poll { env.sut.uiState.isSaving == false }

        XCTAssertEqual(env.repo.saveCallCount, 1)
        XCTAssertEqual(
            env.repo.savedEntities.last,
            SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false)
        )
    }

    func testOnAppearDispatchedTwiceQuicklyRunsOnlyOneLoadEffect() async {
        let env = SettingsEnv()
        let gate = AsyncGate()
        env.repo.loadGate = gate
        env.repo.loadResult = .success(.default)

        env.sut.dispatch(.onAppear)
        env.sut.dispatch(.onAppear)

        await poll { env.repo.loadCallCount >= 1 }
        await settle()
        await gate.open()
        await poll { env.sut.viewState.tag == "content" }

        XCTAssertEqual(env.repo.loadCallCount, 1, "the prior \"load\" effect is cancelled before it calls the use case")
    }
}
