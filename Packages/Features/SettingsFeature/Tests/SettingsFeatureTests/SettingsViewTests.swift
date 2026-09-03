import Core
import SwiftUI
import XCTest
@testable import SettingsFeature

/// The view is deliberately thin; these tests only make sure each `viewState`
/// branch of `body` builds without trapping (behaviour is asserted on the
/// ViewModel). Accessing `.body` runs the `@ViewBuilder` closures.
@MainActor
final class SettingsViewTests: XCTestCase {
    func testBodyBuildsInLoadingState() {
        let view = SettingsView(viewModel: SettingsViewModel(repository: SpySettingsRepository()))
        _ = view.body
    }

    func testBodyBuildsInContentState() async {
        let repo = SpySettingsRepository()
        repo.loadResult = .success(SettingsEntity(isDarkMode: true, language: "vi", notificationsEnabled: false))
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.dispatch(.onAppear)
        await poll { viewModel.viewState.tag == "content" }

        let view = SettingsView(viewModel: viewModel)
        _ = view.body
    }

    func testBodyBuildsInErrorState() async {
        let repo = SpySettingsRepository()
        repo.loadResult = .error(AppError(code: "x", message: "offline"))
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.dispatch(.onAppear)
        await poll { viewModel.viewState.tag == "error" }

        let view = SettingsView(viewModel: viewModel)
        _ = view.body
    }

    func testBodyBuildsWhileSaving() async {
        let repo = SpySettingsRepository()
        repo.loadResult = .success(.default)
        let gate = AsyncGate()
        repo.saveGate = gate
        let viewModel = SettingsViewModel(repository: repo)
        viewModel.dispatch(.onAppear)
        await poll { viewModel.viewState.tag == "content" }
        viewModel.dispatch(.toggleDarkMode)
        await poll { viewModel.uiState.isSaving }

        _ = SettingsView(viewModel: viewModel).body
        await gate.open()
    }
}
