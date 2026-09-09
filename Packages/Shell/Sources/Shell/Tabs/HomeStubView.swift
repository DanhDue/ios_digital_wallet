import AppUIKit
import Platform
import SwiftUI

/// The tab-0 root. Deliberately logic-free — an SF Symbol and a label. Real
/// products replace it with a `HomeFeature`; the template ships a stub so the
/// shell has three tabs out of the box (Source Spec §4.1, G3).
public struct HomeStubView: View {
    @Environment(\.t) private var t: Translations

    public init() {}

    public var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "house")
                .font(.largeTitle)
            Text(t.home.title)
                .font(.headline)
        }
        .padding(AppSpacing.md)
        .accessibilityIdentifier("shell.home.stub")
    }
}

#Preview {
    HomeStubView()
}
