import AppUIKit
import SwiftUI

/// Grouped card container with an uppercase caption header and rounded white/surface background.
public struct SettingsSectionCard<Content: View>: View {
    private let title: String
    @ViewBuilder private let content: () -> Content

    public init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, AppSpacing.xs)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
