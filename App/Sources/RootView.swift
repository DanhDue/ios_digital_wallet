import AppUIKit
import Core
import Framework
import Network
import Platform
import SwiftUI

/// Placeholder host screen for Phase 1. Phase 2 replaces this with the `Shell`
/// package's tab layout (Task 10).
///
/// Until `Shell` lands this view doubles as a **temporary infrastructure
/// linkage probe**: it imports all five infra packages — `Core`, `Framework`,
/// `Network`, `AppUIKit`, `Platform` — and references one real symbol from each
/// so `tuist generate` + `xcodebuild build` prove every framework is linked and
/// embedded in the app target. Delete `infraLinkageProbe` and its use when the
/// real `ShellView` is hosted here.
struct RootView: View {
    /// One real symbol from each of the five infra packages, evaluated so the
    /// linker cannot drop any framework. Removed when `Shell` lands (Task 10).
    private var infraLinkageProbe: String {
        let coreError = AppError(code: "core.linked", message: "Core is linked")
        let frameworkState = ViewState<Int>.loading
        let networkBaseURL = AppEnvironment.debug.baseURL
        let uiKitGutter = AppSpacing.md
        let platformRoute = AppRoutes.SettingsRoot()

        let renderState = switch frameworkState {
        case .loading: "loading"
        case .error: "error"
        case .content: "content"
        }

        return [
            "Core \(coreError.code)",
            "Framework \(renderState)",
            "Network \(networkBaseURL.absoluteString)",
            "AppUIKit gutter \(Int(uiKitGutter))pt",
            "Platform \(String(describing: platformRoute))",
        ].joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("iOS Super App Template — skeleton")
            Text(infraLinkageProbe)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.md)
        .accessibilityIdentifier("core.linked")
    }
}

#Preview {
    RootView()
}
