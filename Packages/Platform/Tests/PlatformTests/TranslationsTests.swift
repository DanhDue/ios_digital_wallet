import Core
import Foundation
import SwiftUI
import XCTest
@testable import Platform

@MainActor
final class TranslationsTests: XCTestCase {
    private final class MockService: LocalizationService {
        var currentLanguageCode: String = "en"
        var translations: [String: String] = [:]

        func setLocale(code: String) {
            currentLanguageCode = code
        }

        func applyDynamicTranslations(_ translations: [String: String], languageCode _: String) {
            self.translations.merge(translations) { _, new in new }
        }

        func translate(_ key: String, default defaultString: String?) -> String {
            translations[key] ?? defaultString ?? key
        }
    }

    func testTranslationsAccessorsDefaultFallbacks() {
        let mock = MockService()
        let sut = Translations(manager: mock)

        // Shell
        XCTAssertEqual(sut.shell.tab.home, "Home")
        XCTAssertEqual(sut.shell.tab.scanner, "Scan")
        XCTAssertEqual(sut.shell.tab.settings, "Settings")

        // Home
        XCTAssertEqual(sut.home.title, "Home")

        // Scanner
        XCTAssertEqual(sut.scanner.title, "Scanner")
        XCTAssertEqual(sut.scanner.comingSoon.title, "Scanner coming soon")
        XCTAssertFalse(sut.scanner.comingSoon.message.isEmpty)

        // Settings
        XCTAssertEqual(sut.settings.title, "Settings")
        XCTAssertEqual(sut.settings.logout, "Logout")
        XCTAssertEqual(sut.settings.loadingLanguage, "Loading language…")
        XCTAssertEqual(sut.settings.saving, "Saving…")
        XCTAssertEqual(sut.settings.account.title, "Account")
        XCTAssertEqual(sut.settings.account.profile, "Edit Profile")
        XCTAssertEqual(sut.settings.account.changePassword, "Change Password")
        XCTAssertEqual(sut.settings.account.twoFactorAuth, "Two-Factor Auth (2FA)")
        XCTAssertEqual(sut.settings.account.twoFactorAuthOn, "On")
        XCTAssertEqual(sut.settings.preferences.title, "Preferences")
        XCTAssertEqual(sut.settings.preferences.currency, "Currency / Units")
        XCTAssertEqual(sut.settings.preferences.currencyUsd, "USD ($)")
        XCTAssertEqual(sut.settings.preferences.language, "Language")
        XCTAssertEqual(sut.settings.preferences.darkMode, "Dark Mode")
        XCTAssertEqual(sut.settings.preferences.notifications, "Push Notifications")
        XCTAssertEqual(sut.settings.developer.title, "Developer")
        XCTAssertEqual(sut.settings.developer.debugMode, "Debug Mode")
        XCTAssertEqual(sut.settings.appInfo.title, "App Info")
        XCTAssertEqual(sut.settings.appInfo.contactSupport, "Contact Support")
        XCTAssertEqual(sut.settings.appInfo.aboutApp, "About App")
        XCTAssertEqual(sut.settings.language.updating, "Updating language...")
    }

    func testTranslationsAccessorsWithDynamicOverrides() {
        let mock = MockService()
        mock.translations = [
            "settings.title": "Cài đặt hệ thống",
            "settings.account.changePassword": "Đổi mật khẩu mới",
            "shell.tab.home": "Trang chính",
        ]
        let sut = Translations(manager: mock)

        XCTAssertEqual(sut.settings.title, "Cài đặt hệ thống")
        XCTAssertEqual(sut.settings.account.changePassword, "Đổi mật khẩu mới")
        XCTAssertEqual(sut.shell.tab.home, "Trang chính")
        // Non-overridden fallback
        XCTAssertEqual(sut.settings.logout, "Logout")
    }

    func testDynamicCallAsFunctionLookup() {
        let mock = MockService()
        mock.translations = ["custom.feature.title": "Ví tiền"]
        let sut = Translations(manager: mock)

        XCTAssertEqual(sut("custom.feature.title", default: "Wallet"), "Ví tiền")
        XCTAssertEqual(sut("unknown.key", default: "Default Text"), "Default Text")
    }

    func testGlobalTAccessor() {
        XCTAssertFalse(t.settings.title.isEmpty)
        XCTAssertFalse(t.shell.tab.home.isEmpty)
    }

    func testEnvironmentValuesTDefaults() {
        let values = EnvironmentValues()
        XCTAssertFalse(values.t.settings.title.isEmpty)
    }
}
