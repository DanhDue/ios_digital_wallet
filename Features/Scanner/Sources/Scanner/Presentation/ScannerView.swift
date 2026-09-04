import AppUIKit
import SwiftUI

/// The Scanner screen (Source Spec §11). A "coming soon" placeholder built on
/// `AppUIKit.AppEmptyStateView` — the template ships Scanner as a stub. Every
/// gesture still funnels through `viewModel.dispatch(_:)` so the MVI discipline
/// is demonstrated end to end.
public struct ScannerView: View {
    @ObservedObject private var viewModel: ScannerViewModel

    public init(viewModel: ScannerViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        AppEmptyStateView(
            title: "Scanner coming soon",
            message: "This tab is a stub in the template — wire a real scanner into ScannerFeature.",
            systemImage: "qrcode.viewfinder"
        )
        .navigationTitle("Scanner")
        .accessibilityIdentifier("scanner.comingSoon")
        .onAppear { viewModel.dispatch(.onAppear) }
    }
}

#Preview {
    ScannerView(viewModel: ScannerModule.makeViewModel())
}
