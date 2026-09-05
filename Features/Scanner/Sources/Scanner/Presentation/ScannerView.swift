import AppUIKit
import Platform
import SwiftUI

/// The Scanner screen (Source Spec §11). A "coming soon" placeholder built on
/// `AppUIKit.AppEmptyStateView` — the template ships Scanner as a stub. Every
/// gesture still funnels through `viewModel.dispatch(_:)` so the MVI discipline
/// is demonstrated end to end.
public struct ScannerView: View {
    @ObservedObject private var viewModel: ScannerViewModel
    @Environment(\.localizationManager) private var localizationManager

    public init(viewModel: ScannerViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        AppEmptyStateView(
            title: localizationManager.translate("scanner.comingSoon.title", default: "Scanner coming soon"),
            message: localizationManager.translate(
                "scanner.comingSoon.message",
                default: "This tab is a stub in the template — wire a real scanner into ScannerFeature."
            ),
            systemImage: "qrcode.viewfinder"
        )
        .navigationTitle(localizationManager.translate("scanner.title", default: "Scanner"))
        .accessibilityIdentifier("scanner.comingSoon")
        .onAppear { viewModel.dispatch(.onAppear) }
    }
}

#Preview {
    ScannerView(viewModel: ScannerModule.makeViewModel())
}
