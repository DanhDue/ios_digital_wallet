import AppUIKit
import SwiftUI

/// A modal dialog overlay that displays a centered progress spinner and optional message,
/// dimming the background without unmounting the underlying view (mirroring Flutter's LoadingMixin).
public struct SettingsLoadingDialogView: View {
    private let message: String?

    public init(message: String? = nil) {
        self.message = message
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(AppSpacing.xl)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            .padding(AppSpacing.xl)
        }
    }
}

public extension View {
    /// Overlays a modal loading dialog on top of the view when `isPresented` is true.
    func settingsLoadingDialog(isPresented: Bool, message: String? = nil) -> some View {
        overlay {
            if isPresented {
                SettingsLoadingDialogView(message: message)
                    .transition(.opacity)
            }
        }
    }
}
