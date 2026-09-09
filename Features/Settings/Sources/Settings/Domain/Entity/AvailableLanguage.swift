import Foundation

/// A language supported by the application.
public struct AvailableLanguage: Equatable, Sendable, Identifiable {
    public var id: String {
        languageCode
    }

    public let languageCode: String
    public let languageName: String
    public let isDefault: Bool
    public let isActive: Bool

    public init(
        languageCode: String,
        languageName: String,
        isDefault: Bool = false,
        isActive: Bool = true
    ) {
        self.languageCode = languageCode
        self.languageName = languageName
        self.isDefault = isDefault
        self.isActive = isActive
    }

    /// Default languages available in the picker on initial cold start before bootstrap.
    public static let defaultLanguages: [AvailableLanguage] = [
        AvailableLanguage(languageCode: "en", languageName: "English (US)", isDefault: true, isActive: true),
        AvailableLanguage(languageCode: "vi", languageName: "Tiếng Việt", isDefault: false, isActive: true),
    ]

    /// Language codes bundled locally with static translations in the app binary (English and Vietnamese).
    public static let bundledLanguageCodes: Set<String> = ["en", "vi"]

    /// Determines whether a language code matches a bundled language (supporting both "vi" and "vi_VN", "en"
    /// and "en_US", etc.).
    public static func isDefaultOrBundled(_ code: String) -> Bool {
        let normalized = code.replacingOccurrences(of: "-", with: "_").lowercased()
        let prefix = normalized.split(separator: "_").first.map(String.init) ?? normalized
        return bundledLanguageCodes.contains(normalized) || bundledLanguageCodes.contains(prefix)
    }
}
