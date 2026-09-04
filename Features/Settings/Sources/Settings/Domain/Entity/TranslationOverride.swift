import Foundation

/// Remote translation overrides downloaded from the backend.
public struct TranslationOverride: Equatable, Sendable {
    public let version: String
    public let translations: [String: String]
    public let checksum: String?

    public init(
        version: String,
        translations: [String: String],
        checksum: String? = nil
    ) {
        self.version = version
        self.translations = translations
        self.checksum = checksum
    }
}
