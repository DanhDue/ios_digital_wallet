import Core
import Foundation
import SwiftUI

/// Manages the application-wide localization and dynamic string overrides.
///
/// Implements a two-tier translation resolution:
/// 1. Dynamic in-memory / cached translation overrides received from the server.
/// 2. Standard bundle localization (`Bundle.main.localizedString`).
/// 3. Fallback default string.
@MainActor
public final class AppLocalizationManager: ObservableObject, LocalizationService {
    public static var shared = AppLocalizationManager()
    public static let languageStorageKey = "app_language_code"
    public static let translationsPrefix = "translations_"

    @Published public private(set) var currentLanguageCode: String
    @Published public private(set) var dynamicOverrides: [String: String]

    private let cache: any CacheStore
    private let eventBus: AppEventBus
    private let bundle: Bundle
    private let catalogStrings: [String: [String: String]]

    public convenience init(
        cache: any CacheStore,
        eventBus: AppEventBus,
        defaultLanguageCode: String = "en"
    ) {
        self.init(
            cache: cache,
            eventBus: eventBus,
            defaultLanguageCode: defaultLanguageCode,
            bundle: .main
        )
    }

    public init(
        cache: any CacheStore = UserDefaultsCacheStore(keyPrefix: "platform.localization."),
        eventBus: AppEventBus = .shared,
        defaultLanguageCode: String = "en",
        bundle: Bundle = .main
    ) {
        self.cache = cache
        self.eventBus = eventBus
        self.bundle = bundle
        catalogStrings = Self.loadCatalog(bundle: bundle)

        let storedCode = cache.get(String.self, key: Self.languageStorageKey)
        let resolvedCode: String = if let storedCode, !storedCode.isEmpty {
            storedCode
        } else {
            defaultLanguageCode
        }
        currentLanguageCode = resolvedCode
        dynamicOverrides = cache.get([String: String].self, key: Self.translationsPrefix + resolvedCode) ?? [:]
    }

    /// Sets the active locale code (e.g. "en", "vi"), loads any cached overrides,
    /// persists the selection, and broadcasts `AppLanguageChanged`.
    public func setLocale(code: String) {
        guard !code.isEmpty, code != currentLanguageCode else { return }
        currentLanguageCode = code
        cache.set(code, key: Self.languageStorageKey)
        dynamicOverrides = cache.get([String: String].self, key: Self.translationsPrefix + code) ?? [:]
        eventBus.publish(AppLanguageChanged(languageCode: code))
    }

    /// Merges dynamic translation overrides for `languageCode`. If `languageCode` matches
    /// the currently active language, the active in-memory dictionary is updated immediately.
    public func applyDynamicTranslations(_ translations: [String: String], languageCode: String) {
        let codePrefix = languageCode.split(separator: "_").first.map(String.init) ?? languageCode
        let currentPrefix = currentLanguageCode.split(separator: "_").first.map(String.init) ?? currentLanguageCode
        if languageCode == currentLanguageCode || codePrefix.lowercased() == currentPrefix.lowercased() {
            var merged = dynamicOverrides
            for (key, value) in translations {
                merged[key] = value
            }
            dynamicOverrides = merged
        }
    }

    /// Resolves a localized string:
    /// 1. Checks dynamic overrides for the key (OTA Server / Cache).
    /// 2. Checks local String Catalog (`Localizable.xcstrings`) for the active language.
    /// 3. Falls back to bundle localization.
    /// 4. Falls back to `defaultString ?? key`.
    public func translate(_ key: String, default defaultString: String? = nil) -> String {
        if let dynamicValue = dynamicOverrides[key] {
            return dynamicValue
        }

        let codePrefix = currentLanguageCode.split(separator: "_").first.map(String.init) ?? currentLanguageCode
        for candidate in [currentLanguageCode, codePrefix] {
            if let localized = catalogStrings[candidate]?[key] {
                return localized
            }
        }

        for candidate in [currentLanguageCode, codePrefix] {
            let langPath = bundle.path(forResource: candidate, ofType: "lproj")
            if let langPath, let langBundle = Bundle(path: langPath) {
                let val = langBundle.localizedString(forKey: key, value: nil, table: nil)
                if val != key {
                    return val
                }
            }
        }

        let bundleValue = bundle.localizedString(forKey: key, value: nil, table: nil)
        if bundleValue != key {
            return bundleValue
        }
        return defaultString ?? key
    }

    private static func loadCatalog(bundle: Bundle) -> [String: [String: String]] {
        var candidates: [URL?] = [
            bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
            Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings"),
            Bundle(for: AppLocalizationManager.self).url(forResource: "Localizable", withExtension: "xcstrings"),
            URL(fileURLWithPath: "App/Resources/Localizable.xcstrings"),
            URL(fileURLWithPath: "Resources/Localizable.xcstrings"),
        ]

        let sourceUrl = URL(fileURLWithPath: #filePath)
        let platformDir = sourceUrl
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let repoRoot = platformDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        candidates.append(platformDir.appendingPathComponent("Resources/Localizable.xcstrings"))
        candidates.append(repoRoot.appendingPathComponent("App/Resources/Localizable.xcstrings"))

        for case let url? in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            if let catalog = try? JSONDecoder().decode(StringCatalogDTO.self, from: data) {
                let flattened = catalog.flattened()
                if !flattened.isEmpty {
                    return flattened
                }
            }
        }
        return [:]
    }
}

private struct StringCatalogDTO: Decodable {
    let strings: [String: StringCatalogEntry]

    func flattened() -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        for (key, entry) in strings {
            guard let locs = entry.localizations else { continue }
            for (lang, loc) in locs {
                if let val = loc.stringUnit?.value {
                    result[lang, default: [:]][key] = val
                }
            }
        }
        return result
    }
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogUnit?
}

private struct StringCatalogUnit: Decodable {
    let value: String
}

public extension EnvironmentValues {
    @Entry var localizationManager: AppLocalizationManager = MainActor.assumeIsolated {
        AppLocalizationManager.shared
    }
}
