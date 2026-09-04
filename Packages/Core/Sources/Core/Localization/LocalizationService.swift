import Foundation

/// Application localization service abstraction.
///
/// Implemented by `AppLocalizationManager` in `Platform` and consumed by
/// feature domain use cases to manipulate active locale and dynamic overrides.
@MainActor
public protocol LocalizationService: AnyObject, Sendable {
    var currentLanguageCode: String { get }
    func setLocale(code: String)
    func applyDynamicTranslations(_ translations: [String: String], languageCode: String)
    func translate(_ key: String, default defaultString: String?) -> String
}

public extension LocalizationService {
    func translate(_ key: String, default defaultString: String? = nil) -> String {
        defaultString ?? key
    }
}
