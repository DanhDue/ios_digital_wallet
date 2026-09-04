import Combine
import Core
import Foundation
import XCTest
@testable import Platform

final class AppLocalizationManagerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    @MainActor
    func testInitWithEmptyCacheDefaultsToEnglish() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        XCTAssertEqual(sut.currentLanguageCode, "en")
        XCTAssertEqual(sut.dynamicOverrides, [:])
    }

    @MainActor
    func testInitWithStoredLanguageCodeLoadsThatLanguage() {
        let cache = InMemoryCacheStore()
        cache.set("vi", key: "app_language_code")
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        XCTAssertEqual(sut.currentLanguageCode, "vi")
    }

    @MainActor
    func testSetLocaleUpdatesCurrentLanguageAndPersistsToCache() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        sut.setLocale(code: "vi")

        XCTAssertEqual(sut.currentLanguageCode, "vi")
        XCTAssertEqual(cache.get(String.self, key: "app_language_code"), "vi")
    }

    @MainActor
    func testSetLocaleBroadcastsAppLanguageChangedToEventBus() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        var receivedEvents: [AppLanguageChanged] = []
        eventBus.on(AppLanguageChanged.self).sink { event in
            receivedEvents.append(event)
        }.store(in: &cancellables)

        sut.setLocale(code: "vi")

        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?.languageCode, "vi")
    }

    @MainActor
    func testSetLocaleWithSameCodeOrEmptyIsNoOp() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        var receivedEvents: [AppLanguageChanged] = []
        eventBus.on(AppLanguageChanged.self).sink { event in
            receivedEvents.append(event)
        }.store(in: &cancellables)

        sut.setLocale(code: "en") // same as default
        sut.setLocale(code: "") // empty

        XCTAssertEqual(receivedEvents.count, 0)
    }

    @MainActor
    func testApplyDynamicTranslationsForActiveLanguageUpdatesOverrides() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        sut.applyDynamicTranslations(["settings.title": "Custom Settings"], languageCode: "en")

        XCTAssertEqual(sut.translate("settings.title"), "Custom Settings")
    }

    @MainActor
    func testApplyDynamicTranslationsForDifferentLanguageDoesNotPolluteCurrentOverrides() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        sut.applyDynamicTranslations(["custom.key": "Cài đặt"], languageCode: "vi")

        // Current language is "en", so "vi" translations should not be active
        XCTAssertEqual(sut.translate("custom.key", default: "Default Title"), "Default Title")
    }

    @MainActor
    func testTranslateReturnsFallbackWhenKeyNotFound() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppLocalizationManager(cache: cache, eventBus: eventBus)

        let result = sut.translate("nonexistent.key", default: "Default Text")

        XCTAssertEqual(result, "Default Text")
    }
}
