import AppUIKit
import Core
import SwiftUI

/// The Settings form (Source Spec §4.4 / §11). Deliberately thin: it renders
/// `viewModel.viewState` and funnels every gesture through
/// `viewModel.dispatch(_:)` — all behaviour and every test assertion live on
/// `SettingsViewModel`.
public struct SettingsView: View {
    @ObservedObject private var viewModel: SettingsViewModel

    /// Language tags offered by the picker. Presentational only — the ViewModel
    /// accepts any non-empty tag.
    private let languageOptions = ["en", "vi", "ja", "fr"]

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("Settings")
            .onAppear { viewModel.dispatch(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            AppLoadingView()
        case let .error(error):
            AppErrorView(message: Self.message(for: error)) {
                viewModel.dispatch(.onAppear)
            }
        case .content:
            form
        }
    }

    private var form: some View {
        let settings = viewModel.uiState.settings
        return List {
            Section("Preferences") {
                Toggle("Dark Mode", isOn: toggleBinding(
                    value: settings.isDarkMode,
                    action: .toggleDarkMode
                ))
                Toggle("Notifications", isOn: toggleBinding(
                    value: settings.notificationsEnabled,
                    action: .toggleNotifications
                ))
            }
            Section("Language") {
                ForEach(languageOptions, id: \.self) { code in
                    languageRow(code: code, isSelected: settings.language == code)
                }
            }
            if viewModel.uiState.isSaving {
                Text("Saving…").foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private func languageRow(code: String, isSelected: Bool) -> some View {
        HStack {
            Text(code.uppercased())
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.dispatch(.selectLanguage(code)) }
    }

    private func toggleBinding(value: Bool, action: SettingsAction) -> Binding<Bool> {
        Binding(
            get: { value },
            set: { _ in viewModel.dispatch(action) }
        )
    }

    private static func message(for error: Error) -> String {
        (error as? AppError)?.message ?? "Something went wrong."
    }
}
