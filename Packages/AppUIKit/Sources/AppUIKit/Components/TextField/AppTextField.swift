import SwiftUI

/// A presentational text field bound to caller-owned state via `@Binding`. The
/// placeholder shows while the bound text is empty. `isSecure` switches to a
/// `SecureField`. No ViewModel — all state lives with the caller.
public struct AppTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool

    public init(_ placeholder: String, text: Binding<String>, isSecure: Bool = false) {
        self.placeholder = placeholder
        _text = text
        self.isSecure = isSecure
    }

    /// Pure predicate: the placeholder is visible while the bound text is empty.
    public var showsPlaceholder: Bool {
        text.isEmpty
    }

    public var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(AppFont.body)
        .padding(AppSpacing.sm)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs, style: .continuous))
        .accessibilityLabel(Text(placeholder))
    }
}

#Preview {
    struct Harness: View {
        @State private var email = ""
        @State private var password = "hunter2"
        var body: some View {
            VStack(spacing: AppSpacing.md) {
                AppTextField("Email", text: $email)
                AppTextField("Password", text: $password, isSecure: true)
            }
            .padding()
        }
    }
    return Harness()
}
