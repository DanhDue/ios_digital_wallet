import SwiftUI

/// A centered progress indicator exposed to assistive tech as a single element
/// labelled "Loading" (override via `label:`).
public struct AppLoadingView: View {
    /// The default accessibility label.
    public static let defaultLabel = "Loading"

    private let label: String

    public init(label: String = AppLoadingView.defaultLabel) {
        self.label = label
    }

    /// The accessibility label this view exposes.
    public var accessibilityLabelText: String {
        label
    }

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.lg)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    AppLoadingView()
}
