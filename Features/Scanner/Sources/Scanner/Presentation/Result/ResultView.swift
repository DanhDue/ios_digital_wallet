import AppUIKit
import Platform
import SwiftUI

/// The `Result` sub-screen (Source Spec §4.4 / §11) — renders the code the
/// Scanner tab just decoded. Thin: it renders `viewModel.viewState` and
/// funnels every gesture through `viewModel.dispatch(_:)`.
///
/// See: Features/Settings/Sources/Settings/Presentation/SettingsView.swift
public struct ResultView: View {
    @ObservedObject private var viewModel: ResultViewModel
    @Environment(\.t) private var t: Translations

    public init(viewModel: ResultViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        content
            .navigationTitle(t.scanner.result.title)
            .onAppear { viewModel.dispatch(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            AppLoadingView()
        case .error:
            AppErrorView(message: t.scanner.result.errorMessage) {
                viewModel.dispatch(.onAppear)
            }
        case .content:
            VStack(spacing: AppSpacing.sm) {
                Text(t.scanner.result.codeLabel)
                    .font(.headline)
                Text(viewModel.uiState.code)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("scanner.result.code")
            }
            .padding(AppSpacing.md)
        }
    }
}

#Preview {
    ResultView(viewModel: ResultViewModel(code: "ABC123"))
}
