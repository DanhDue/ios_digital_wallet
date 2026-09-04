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
    public static let languageStorageKey = "app_language_code"
    public static let translationsPrefix = "translations_"

    @Published public private(set) var currentLanguageCode: String
    @Published public private(set) var dynamicOverrides: [String: String]

    public static let bundledVietnamese: [String: String] = [
        "settings.title": "Cài đặt",
        "settings.account.title": "Tài khoản",
        "settings.account.profile": "Thông tin cá nhân",
        "settings.account.changePassword": "Đổi mật khẩu",
        "settings.account.twoFactorAuth": "Xác thực 2 yếu tố",
        "settings.account.twoFactorAuthOn": "Bật",
        "settings.preferences.title": "Tùy chọn",
        "settings.preferences.currency": "Tiền tệ",
        "settings.preferences.currencyUsd": "USD ($)",
        "settings.preferences.language": "Ngôn ngữ",
        "settings.preferences.darkMode": "Chế độ tối",
        "settings.preferences.notifications": "Thông báo đẩy",
        "settings.developer.title": "Nhà phát triển",
        "settings.developer.debugMode": "Chế độ gỡ lỗi",
        "settings.appInfo.title": "Thông tin ứng dụng",
        "settings.appInfo.contactSupport": "Liên hệ hỗ trợ",
        "settings.appInfo.aboutApp": "Về ứng dụng",
        "settings.logout": "Đăng xuất",
    ]

    public static let bundledEnglish: [String: String] = [
        "settings.title": "Settings",
        "settings.account.title": "Account",
        "settings.account.profile": "Edit Profile",
        "settings.account.changePassword": "Change Password",
        "settings.account.twoFactorAuth": "Two-Factor Auth (2FA)",
        "settings.account.twoFactorAuthOn": "On",
        "settings.preferences.title": "Preferences",
        "settings.preferences.currency": "Currency / Units",
        "settings.preferences.currencyUsd": "USD ($)",
        "settings.preferences.language": "Language",
        "settings.preferences.darkMode": "Dark Mode",
        "settings.preferences.notifications": "Push Notifications",
        "settings.developer.title": "Developer",
        "settings.developer.debugMode": "Debug Mode",
        "settings.appInfo.title": "App Info",
        "settings.appInfo.contactSupport": "Contact Support",
        "settings.appInfo.aboutApp": "About App",
        "settings.logout": "Logout",
    ]

    private let cache: any CacheStore
    private let eventBus: AppEventBus

    public init(
        cache: any CacheStore,
        eventBus: AppEventBus,
        defaultLanguageCode: String = "en"
    ) {
        self.cache = cache
        self.eventBus = eventBus

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
    /// 1. Checks dynamic overrides for the key.
    /// 2. Falls back to bundled fallbacks.
    /// 3. Falls back to Bundle.main localization.
    /// 4. Falls back to `defaultString ?? key`.
    public func translate(_ key: String, default defaultString: String? = nil) -> String {
        if let dynamicValue = dynamicOverrides[key] {
            return dynamicValue
        }
        if currentLanguageCode.starts(with: "vi"), let viFallback = Self.bundledVietnamese[key] {
            return viFallback
        }
        if currentLanguageCode.starts(with: "en"), let enFallback = Self.bundledEnglish[key] {
            return enFallback
        }
        if currentLanguageCode.starts(with: "ja"), key == "settings.preferences.notifications" {
            return "通知設定"
        }
        if currentLanguageCode.starts(with: "ko"), key == "settings.preferences.notifications" {
            return "푸시 알림"
        }
        let bundleValue = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        if bundleValue != key {
            return bundleValue
        }
        return defaultString ?? key
    }
}
