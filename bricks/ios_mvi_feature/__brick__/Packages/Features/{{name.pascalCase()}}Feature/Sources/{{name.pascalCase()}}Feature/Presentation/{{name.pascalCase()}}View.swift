import AppUIKit
import Core
import SwiftUI

/// The `{{name.pascalCase()}}` screen (Source Spec §4.4 / §11). Deliberately
/// thin: it renders `viewModel.viewState` and funnels every gesture through
/// `viewModel.dispatch(_:)` — all behaviour and every test assertion live on
/// `{{name.pascalCase()}}ViewModel`.
///
/// See: Packages/Features/SettingsFeature/Sources/SettingsFeature/Presentation/SettingsView.swift
public struct {{name.pascalCase()}}View: View {
    @ObservedObject private var viewModel: {{name.pascalCase()}}ViewModel

    public init(viewModel: {{name.pascalCase()}}ViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle("{{name.pascalCase()}}")
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
        let entity = viewModel.uiState.entity
        return List {
            Section("{{name.pascalCase()}}") {
                Text(entity.title)
                Button("Increment (\(entity.count))") {
                    viewModel.dispatch(.increment)
                }
            }
            if viewModel.uiState.isSaving {
                Text("Saving…").foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private static func message(for error: Error) -> String {
        (error as? AppError)?.message ?? "Something went wrong."
    }
}
