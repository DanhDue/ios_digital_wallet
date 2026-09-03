import SwiftUI

public extension View {
    /// Standard card container: padded, on `appSurface`, rounded corners.
    func appCard() -> some View {
        padding(AppSpacing.md)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm, style: .continuous))
    }

    /// Fills the available width, centering the content — the standard shape for
    /// state views (`AppLoadingView`, `AppErrorView`, `AppEmptyStateView`).
    func appFillWidth() -> some View {
        frame(maxWidth: .infinity)
    }

    /// Applies `transform` only when `condition` is true. Keeps call sites free
    /// of `if`-ladder view builders.
    @ViewBuilder
    func appApply(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
