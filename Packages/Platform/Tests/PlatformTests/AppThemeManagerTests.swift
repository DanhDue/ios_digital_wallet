import Combine
import Core
import SwiftUI
import XCTest
@testable import Platform

final class AppThemeManagerTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    @MainActor
    func testInitWithEmptyCacheDefaultsToSystemMode() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        XCTAssertEqual(sut.mode, .system)
        XCTAssertNil(sut.colorScheme)
    }

    @MainActor
    func testInitWithStoredDarkValueLoadsDarkMode() {
        let cache = InMemoryCacheStore()
        cache.set(AppThemeMode.dark.rawValue, key: "app_theme_mode")
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        XCTAssertEqual(sut.mode, .dark)
        XCTAssertEqual(sut.colorScheme, .dark)
    }

    @MainActor
    func testInitWithStoredLightValueLoadsLightMode() {
        let cache = InMemoryCacheStore()
        cache.set(AppThemeMode.light.rawValue, key: "app_theme_mode")
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        XCTAssertEqual(sut.mode, .light)
        XCTAssertEqual(sut.colorScheme, .light)
    }

    @MainActor
    func testSetModeUpdatesPublishedPropertyAndPersistsToCache() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        sut.setMode(.dark)

        XCTAssertEqual(sut.mode, .dark)
        XCTAssertEqual(sut.colorScheme, .dark)
        XCTAssertEqual(cache.get(String.self, key: "app_theme_mode"), AppThemeMode.dark.rawValue)
    }

    @MainActor
    func testSetModeBroadcastsThemeModeChangedToAppEventBus() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        var receivedEvents: [ThemeModeChanged] = []
        eventBus.on(ThemeModeChanged.self).sink { event in
            receivedEvents.append(event)
        }.store(in: &cancellables)

        sut.setMode(.dark)

        XCTAssertEqual(receivedEvents.count, 1)
        XCTAssertEqual(receivedEvents.first?.mode, .dark)
    }

    @MainActor
    func testSetModeWithSameModeIsNoOp() {
        let cache = InMemoryCacheStore()
        let eventBus = AppEventBus()
        let sut = AppThemeManager(cache: cache, eventBus: eventBus)

        var receivedEvents: [ThemeModeChanged] = []
        eventBus.on(ThemeModeChanged.self).sink { event in
            receivedEvents.append(event)
        }.store(in: &cancellables)

        sut.setMode(.system) // same as initial

        XCTAssertEqual(receivedEvents.count, 0)
    }
}
