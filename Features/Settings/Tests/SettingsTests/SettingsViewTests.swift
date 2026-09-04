import Core
import SwiftUI
import XCTest
@testable import Settings

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

    func testLanguagePickerBottomSheetBuilds() {
        var selectedCode: String?
        let sheet = LanguagePickerBottomSheet(
            languages: AvailableLanguage.defaultLanguages,
            currentLanguageCode: "vi",
            onSelect: { selectedCode = $0 }
        )
        _ = sheet.body
        XCTAssertNil(selectedCode)
    }

    func testLanguagePickerBottomSheetBuildsWithManyLanguages() {
        let many = (0 ..< 12).map {
            AvailableLanguage(languageCode: "code\($0)", languageName: "Lang \($0)", isDefault: false, isActive: true)
        }
        let sheet = LanguagePickerBottomSheet(
            languages: many,
            currentLanguageCode: "code0",
            onSelect: { _ in }
        )
        _ = sheet.body
    }

    func testSettingsSectionCardBuilds() {
        let card = SettingsSectionCard(title: "Header") {
            Text("Content")
        }
        _ = card.body
    }

    func testSettingsItemRowVariantsBuild() {
        let row1 = SettingsItemRow(
            icon: "person.fill",
            title: "Profile",
            accessory: .chevron,
            action: {}
        )
        _ = row1.body

        let row2 = SettingsItemRow(
            icon: "moon.fill",
            title: "Dark",
            accessory: .toggle(.constant(true))
        )
        _ = row2.body

        let row3 = SettingsItemRow(
            icon: "globe",
            title: "Lang",
            accessory: .navigation(value: "English", tag: "Bật"),
            action: {}
        )
        _ = row3.body

        let row4 = SettingsItemRow(
            icon: "info.circle",
            title: "Version",
            accessory: .value("1.0.0")
        )
        _ = row4.body
    }
}
