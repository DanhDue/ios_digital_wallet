import Core
import SwiftUI

/// A presentational error panel: a message and an optional retry affordance.
/// Passing `retry: nil` (or omitting it) hides the retry button entirely.
public struct AppErrorView: View {
    private let message: String
    private let retry: (() -> Void)?

    public init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }

    /// Convenience for rendering a `Core.AppError` — uses its `message`.
    public init(_ error: AppError, retry: (() -> Void)? = nil) {
        self.init(message: error.message, retry: retry)
    }

    /// Pure predicate: the retry button is shown only when a closure was given.
    public var showsRetry: Bool {
        retry != nil
    }

    /// Invokes the retry closure if present. Backs the retry button's action and
    /// lets tests drive the behaviour without UI hit-testing.
    func performRetry() {
        retry?()
    }

    public var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.largeTitle)
                .foregroundStyle(Color.appDestructive)
            Text(message)
                .font(AppFont.body)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            if showsRetry {
                AppButton("Retry", style: .secondary, action: performRetry)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }
}

#Preview {
    VStack(spacing: AppSpacing.xl) {
        AppErrorView(message: "Something went wrong. Please try again.", retry: {})
        AppErrorView(message: "No retry offered for this one.")
    }
    .padding()
}
