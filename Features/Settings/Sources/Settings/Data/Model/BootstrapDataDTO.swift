import Foundation

/// Wire representation of bootstrap data from `POST /api/v1/settings/sync/bootstrap`.
struct BootstrapDataDTO: Codable, Equatable, Sendable {
    let availableLanguages: [AvailableLanguageDTO]?

    enum CodingKeys: String, CodingKey {
        case availableLanguages = "available_languages"
    }

    init(availableLanguages: [AvailableLanguageDTO]? = nil) {
        self.availableLanguages = availableLanguages
    }
}
