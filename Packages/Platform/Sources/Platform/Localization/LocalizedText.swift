import SwiftUI

/// A SwiftUI view that renders dynamic localized text via `AppLocalizationManager`.
///
/// It reads the active `AppLocalizationManager` from SwiftUI's environment, automatically
/// displaying either the server dynamic override, the local String Catalog (`Localizable.xcstrings`),
/// or the fallback default text.
public struct LocalizedText: View {
    @Environment(\.localizationManager) private var localizationManager
    private let key: String
    private let defaultText: String?

    public init(_ key: String, default defaultText: String? = nil) {
        self.key = key
        self.defaultText = defaultText
    }

    public var body: some View {
        Text(localizationManager.translate(key, default: defaultText))
    }
}
