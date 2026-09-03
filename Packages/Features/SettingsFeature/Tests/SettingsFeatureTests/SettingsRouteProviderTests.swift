import Platform
import SwiftUI
import XCTest
@testable import SettingsFeature

@MainActor
final class SettingsRouteProviderTests: XCTestCase {
    private func makeProvider(onBuild: @escaping () -> Void = {}) -> SettingsRouteProvider {
        SettingsRouteProvider {
            onBuild()
            return SettingsViewModel(repository: SpySettingsRepository())
        }
    }

    func testCanHandleIsTrueForSettingsRootOnly() {
        let provider = makeProvider()

        XCTAssertTrue(provider.canHandle(AppRoutes.SettingsRoot()))
        XCTAssertFalse(provider.canHandle(AppRoutes.ScannerRoot()))
    }

    func testDestinationForSettingsRootReturnsAViewAndDefersViewModelConstruction() {
        var built = 0
        let provider = makeProvider { built += 1 }

        let view = provider.destination(for: AppRoutes.SettingsRoot())

        XCTAssertTrue(String(describing: type(of: view)).contains("AnyView"))
        XCTAssertEqual(built, 0, "the ViewModel is built lazily, inside the SwiftUI body — not at resolve time")
    }

    func testDeferredSettingsViewBodyBuildsTheViewModelExactlyOnce() {
        var built = 0
        let deferred = DeferredSettingsView {
            built += 1
            return SettingsViewModel(repository: SpySettingsRepository())
        }

        _ = deferred.body

        XCTAssertEqual(built, 1)
    }

    func testDestinationForAForeignRouteDoesNotBuildAViewModel() {
        var built = 0
        let provider = makeProvider { built += 1 }

        _ = provider.destination(for: AppRoutes.ScannerRoot())

        XCTAssertEqual(built, 0)
    }

    func testRegistersAndResolvesThroughAppRouter() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        router.register(makeProvider())

        // Exercised the same way the shell resolves a tab root.
        let resolved = router.destination(for: AppRoutes.SettingsRoot())
        XCTAssertNotNil(resolved)
    }

    // MARK: Composition root

    func testModuleFactoryBuildsAWorkingProviderOverACacheStore() {
        let logger = SpyLogger()
        let cache = InMemoryCacheStore(logger: logger)
        let provider = SettingsFeatureModule.makeRouteProvider(cache: cache, logger: logger)

        XCTAssertTrue(provider.canHandle(AppRoutes.SettingsRoot()))
        _ = provider.destination(for: AppRoutes.SettingsRoot())
    }

    func testModuleFactoryBuildsAViewModelThatLoadsFromTheCache() async {
        let logger = SpyLogger()
        let cache = InMemoryCacheStore(logger: logger)
        let seeded = SettingsRepositoryImpl(cache: cache, logger: logger)
        _ = await seeded.save(SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false))

        let viewModel = SettingsFeatureModule.makeViewModel(cache: cache, logger: logger)
        viewModel.dispatch(.onAppear)
        await poll { viewModel.viewState.tag == "content" }

        XCTAssertEqual(viewModel.uiState.settings.language, "vi")
    }
}
