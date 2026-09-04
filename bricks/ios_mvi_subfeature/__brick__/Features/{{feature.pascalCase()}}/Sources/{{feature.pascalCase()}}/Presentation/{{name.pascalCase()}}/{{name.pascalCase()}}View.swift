import AppUIKit
import SwiftUI

/// The `{{name.pascalCase()}}` sub-screen (Source Spec §4.4 / §11). Thin: it
/// renders `viewModel.viewState` and funnels every gesture through
/// `viewModel.dispatch(_:)`.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsView.swift
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
        case .error:
            AppErrorView(message: "Something went wrong.") {
                viewModel.dispatch(.onAppear)
            }
        case .content:
            Button("Increment (\(viewModel.uiState.count))") {
                viewModel.dispatch(.increment)
            }
        }
    }
}
