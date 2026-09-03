import SwiftUI
import XCTest
@testable import Platform

@MainActor
final class AppRouterTests: XCTestCase {
    // MARK: Construction

    func testInitCreatesOneEmptyPathPerTabAndSelectsInitialTab() {
        let router = AppRouter(tabCount: 3, initialTab: 2)

        XCTAssertEqual(router.selectedTab, 2)
        XCTAssertEqual(router.tabPaths.count, 3)
        XCTAssertTrue(router.tabPaths.allSatisfy(\.isEmpty))
    }

    func testInitWithZeroTabsProducesNoPathsAndDoesNotCrash() {
        let router = AppRouter(tabCount: 0, initialTab: 0)

        XCTAssertTrue(router.tabPaths.isEmpty)
    }

    // MARK: Happy path

    func testNavigateWithExplicitTabAppendsToThatTabOnly() {
        let router = AppRouter(tabCount: 3, initialTab: 0)

        router.navigate(to: AppRoutes.SettingsRoot(), inTab: 2)

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 0, 1])
    }

    func testNavigateWithoutTabTargetsSelectedTab() {
        let router = AppRouter(tabCount: 3, initialTab: 1)

        router.navigate(to: RouteA())

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 1, 0])
    }

    func testDestinationReturnsViewFromFirstMatchingProvider() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let first = MockRouteProvider<RouteA>()
        let second = MockRouteProvider<RouteA>()
        router.register(first)
        router.register(second)

        _ = router.destination(for: RouteA())

        XCTAssertEqual(first.destinationCallCount, 1)
        XCTAssertEqual(second.destinationCallCount, 0)
        XCTAssertTrue(first.lastRoute is RouteA)
    }

    // MARK: Boundary / equivalence

    func testPopOnEmptyPathIsANoOp() {
        let router = AppRouter(tabCount: 2, initialTab: 0)

        router.pop(inTab: 0)

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 0])
    }

    func testPopRemovesExactlyOneLevel() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        router.navigate(to: RouteB(), inTab: 0)

        router.pop(inTab: 0)

        XCTAssertEqual(router.tabPaths[0].count, 1)
    }

    func testPopToRootEmptiesOnlyTheGivenTab() {
        let router = AppRouter(tabCount: 3, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        router.navigate(to: RouteA(), inTab: 1)
        router.navigate(to: RouteA(), inTab: 2)
        router.navigate(to: RouteA(), inTab: 2)
        router.navigate(to: RouteA(), inTab: 2)

        router.popToRoot(inTab: 1)

        XCTAssertEqual(router.tabPaths.map(\.count), [2, 0, 3])
    }

    func testDestinationWithNoMatchingProviderInvokesNoProvider() {
        let router = AppRouter(tabCount: 1, initialTab: 0)
        let provider = MockRouteProvider<RouteA>()
        router.register(provider)

        _ = router.destination(for: RouteB())

        XCTAssertEqual(provider.destinationCallCount, 0)
    }

    func testNavigateWithOutOfRangeTabIsIgnored() {
        let router = AppRouter(tabCount: 2, initialTab: 0)

        router.navigate(to: RouteA(), inTab: 5)
        router.navigate(to: RouteA(), inTab: -1)

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 0])
    }

    func testPopWithOutOfRangeTabIsIgnored() {
        let router = AppRouter(tabCount: 2, initialTab: 0)

        router.pop(inTab: 9)
        router.pop(inTab: -3)

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 0])
    }

    func testPopToRootWithOutOfRangeTabIsIgnored() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)

        router.popToRoot(inTab: 9)

        XCTAssertEqual(router.tabPaths.map(\.count), [1, 0])
    }

    func testSwitchTabWithOutOfRangeIndexIsIgnored() {
        let router = AppRouter(tabCount: 2, initialTab: 0)

        router.switchTab(9)

        XCTAssertEqual(router.selectedTab, 0)
    }

    // MARK: State transitions — per-tab isolation

    func testNavigateTwiceInTab0ThenSwitchToTab1AndNavigateOnce() {
        let router = AppRouter(tabCount: 2, initialTab: 0)

        router.navigate(to: RouteA())
        router.navigate(to: RouteB())
        router.switchTab(1)
        router.navigate(to: RouteA())

        XCTAssertEqual(router.selectedTab, 1)
        XCTAssertEqual(router.tabPaths[0].count, 2, "tab 0 stack must be untouched by a tab 1 navigate")
        XCTAssertEqual(router.tabPaths[1].count, 1)
    }

    func testSwitchingTabsPreservesBothStacks() {
        let router = AppRouter(tabCount: 2, initialTab: 0)
        router.navigate(to: RouteA(), inTab: 0)
        router.navigate(to: RouteB(), inTab: 0)
        router.navigate(to: RouteA(), inTab: 1)
        router.navigate(to: RouteB(), inTab: 1)
        router.navigate(to: RouteA(), inTab: 1)

        router.switchTab(1)
        router.switchTab(0)

        XCTAssertEqual(router.tabPaths.map(\.count), [2, 3])
        XCTAssertEqual(router.selectedTab, 0)
    }

    func testReselectingActiveTabViaPopToRootClearsOnlyThatTab() {
        let router = AppRouter(tabCount: 2, initialTab: 1)
        router.navigate(to: RouteA(), inTab: 0)
        router.navigate(to: RouteB(), inTab: 0)
        router.navigate(to: RouteA(), inTab: 1)
        router.navigate(to: RouteB(), inTab: 1)

        router.popToRoot(inTab: router.selectedTab)

        XCTAssertEqual(router.tabPaths.map(\.count), [2, 0])
    }

    func testPopAndPopToRootWithoutArgumentActOnSelectedTab() {
        let router = AppRouter(tabCount: 3, initialTab: 2)
        router.navigate(to: RouteA())
        router.navigate(to: RouteB())
        router.navigate(to: RouteA(), inTab: 0)

        router.pop()
        XCTAssertEqual(router.tabPaths.map(\.count), [1, 0, 1])

        router.popToRoot()
        XCTAssertEqual(router.tabPaths.map(\.count), [1, 0, 0])
    }

    // MARK: Async / race

    func testTenRapidNavigateCallsLeaveDepthExactlyTenAndUnwindCleanly() {
        let router = AppRouter(tabCount: 1, initialTab: 0)

        for value in 0 ..< 10 {
            router.navigate(to: NumberedRoute(value: value), inTab: 0)
        }

        // Exactly 10 entries: no append was lost, duplicated, or interleaved
        // with another tab (MainActor isolation serialises the calls).
        XCTAssertEqual(router.tabPaths[0].count, 10)

        // Unwinding one level at a time reaches root in exactly 10 pops — proof
        // that each navigate contributed one, and only one, stack entry.
        for expectedRemaining in stride(from: 9, through: 0, by: -1) {
            router.pop(inTab: 0)
            XCTAssertEqual(router.tabPaths[0].count, expectedRemaining)
        }
    }

    func testNavigateInOneTabNeverMutatesAnotherTabsDepth() {
        let router = AppRouter(tabCount: 4, initialTab: 0)

        for _ in 0 ..< 7 {
            router.navigate(to: RouteA(), inTab: 2)
        }

        XCTAssertEqual(router.tabPaths.map(\.count), [0, 0, 7, 0])
    }
}
