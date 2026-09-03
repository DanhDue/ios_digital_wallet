import Core
import SwiftUI

/// Placeholder host screen for Phase 0. Phase 1 replaces this with the `Shell`
/// package's tab layout.
struct RootView: View {
    /// Temporary proof that the `Core` package links into the app target.
    /// Removed when `Shell` lands (Task 10).
    private var coreLinkageProbe: String {
        AppError(code: "core.linked", message: "Core package is linked").code
    }

    var body: some View {
        Text("iOS Super App Template — skeleton")
            .padding()
            .accessibilityIdentifier(coreLinkageProbe)
    }
}

#Preview {
    RootView()
}
