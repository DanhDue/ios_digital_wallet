import Foundation

/// Wire representation of user preferences.
struct UserPreferencesDTO: Codable, Equatable, Sendable {
    let selectedLanguage: String?
    let selectedThemeId: String?

    enum CodingKeys: String, CodingKey {
        case selectedLanguage = "selected_language"
        case selectedThemeId = "selected_theme_id"
    }

    init(selectedLanguage: String? = nil, selectedThemeId: String? = nil) {
        self.selectedLanguage = selectedLanguage
        self.selectedThemeId = selectedThemeId
    }
}
