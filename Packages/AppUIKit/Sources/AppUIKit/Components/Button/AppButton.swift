import SwiftUI

/// A presentational button with three visual styles and independent `enabled` /
/// `loading` states. Purely a closure sink — no ViewModel, no observable object.
///
/// * `loading: true` swaps the label for a spinner and suppresses taps.
/// * `enabled: false` renders the disabled treatment and suppresses taps.
/// * Otherwise a tap invokes `action` exactly once.
public struct AppButton: View {
    /// Visual treatment.
    public enum Style: Equatable, Sendable {
        case primary
        case secondary
        case destructive
    }

    private let title: String
    private let style: Style
    private let isEnabled: Bool
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        enabled: Bool = true,
        loading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        isEnabled = enabled
        isLoading = loading
        self.action = action
    }

    /// Pure predicate: a tap is honoured only when enabled and not loading.
    /// Exposed so the suppression rule is unit-testable without UI hit-testing.
    public var acceptsTap: Bool {
        isEnabled && !isLoading
    }

    /// Tap entry point. A no-op unless `acceptsTap`.
    public func handleTap() {
        guard acceptsTap else {
            return
        }
        action()
    }

    public var body: some View {
        Button(action: handleTap) {
            ZStack {
                Text(title)
                    .font(AppFont.button)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.md)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm, style: .continuous))
        .opacity(isEnabled ? 1 : 0.4)
        .disabled(!acceptsTap)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    private var foreground: Color {
        switch style {
        case .primary, .destructive: .white
        case .secondary: .appTextPrimary
        }
    }

    private var background: Color {
        switch style {
        case .primary: .appPrimary
        case .secondary: .appSurface
        case .destructive: .appDestructive
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        AppButton("Primary") {}
        AppButton("Secondary", style: .secondary) {}
        AppButton("Destructive", style: .destructive) {}
        AppButton("Loading", loading: true) {}
        AppButton("Disabled", enabled: false) {}
    }
    .padding()
}
