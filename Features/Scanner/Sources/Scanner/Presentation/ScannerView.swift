import AppUIKit
import Platform
import SwiftUI

/// The Scanner screen (Source Spec §11). A "coming soon" placeholder built on
/// `AppUIKit.AppEmptyStateView` — the template ships Scanner as a stub. Every
/// gesture still funnels through `viewModel.dispatch(_:)` so the MVI discipline
/// is demonstrated end to end.
public struct ScannerView: View {
    @ObservedObject private var viewModel: ScannerViewModel
    @Environment(\.t) private var t: Translations

    public init(viewModel: ScannerViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        AppEmptyStateView(
            title: t.scanner.comingSoon.title,
            message: t.scanner.comingSoon.message,
            systemImage: "qrcode.viewfinder"
        )
        .navigationTitle(t.scanner.title)
        .accessibilityIdentifier("scanner.comingSoon")
        .onAppear { viewModel.dispatch(.onAppear) }
    }
}

#Preview {
    ScannerView(viewModel: ScannerViewModel())
}
