import Foundation

/// Wire representation of a supported language from the backend.
struct AvailableLanguageDTO: Codable, Equatable, Sendable {
    let languageCode: String
    let languageName: String
    let isDefault: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case languageCode = "language_code"
        case languageName = "language_name"
        case isDefault = "is_default"
        case isActive = "is_active"
    }

    init(
        languageCode: String,
        languageName: String,
        isDefault: Bool? = nil,
        isActive: Bool? = nil
    ) {
        self.languageCode = languageCode
        self.languageName = languageName
        self.isDefault = isDefault
        self.isActive = isActive
    }
}
