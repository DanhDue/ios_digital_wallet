import SwiftUI

/// A presentational empty-state placeholder: an SF Symbol, a title, and optional
/// supporting text. Long titles wrap rather than crash or clip.
public struct AppEmptyStateView: View {
    private let title: String
    private let message: String?
    private let systemImage: String

    public init(title: String, message: String? = nil, systemImage: String = "tray") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    /// Pure predicate: supporting text is rendered only when present and non-empty.
    public var showsMessage: Bool {
        !(message ?? "").isEmpty
    }

    public var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.appTextSecondary)
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)
            if showsMessage, let message {
                Text(message)
                    .font(AppFont.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }
}

#Preview {
    VStack(spacing: AppSpacing.xl) {
        AppEmptyStateView(title: "Nothing here yet")
        AppEmptyStateView(
            title: "No results",
            message: "Try a different search term.",
            systemImage: "magnifyingglass"
        )
    }
    .padding()
}
