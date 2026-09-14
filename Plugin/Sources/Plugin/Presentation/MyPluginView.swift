import SwiftUI

/// Standalone SwiftUI view rendering the plugin UI.
public struct MyPluginView: View {
    @StateObject private var viewModel: MyPluginViewModel

    public init(viewModel: MyPluginViewModel? = nil) {
        let resolvedViewModel = viewModel ?? PluginContainer.shared.myPluginViewModel()
        _viewModel = StateObject(wrappedValue: resolvedViewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            switch viewModel.state {
            case .idle:
                Text("Idle")
                    .foregroundColor(.secondary)
            case .loading:
                ProgressView("Loading plugin data...")
            case let .loaded(data):
                Text(data.title)
                    .font(.headline)
                Text("ID: \(data.id)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("Refresh") {
                    viewModel.dispatch(action: .refresh)
                }
            case let .error(message):
                Text("Error: \(message)")
                    .foregroundColor(.red)
                Button("Retry") {
                    viewModel.dispatch(action: .load)
                }
            }
        }
        .padding()
        .onAppear {
            if viewModel.state == .idle {
                viewModel.dispatch(action: .load)
            }
        }
    }
}
