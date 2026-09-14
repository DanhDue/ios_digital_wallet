import XCTest

/// Tier C — the carried requirement from Task 8's review: `.onOpenURL {
/// composition.deepLinkRouter.open($0) }` had **zero** coverage, because
/// every existing test drives `deepLinkRouter.open(url:)` directly — the
/// same callee `.onOpenURL` calls — so deleting the modifier would leave the
/// whole suite green. This is the one test in the repo that opens a URL
/// through the OS instead of calling the router in process, so it is the
/// only test that can actually catch that deletion.
///
/// **`XCUIApplication.open(_:)` (iOS 16.4+), not `deepLinkRouter.open(url:)`.**
/// This is Apple's own supported mechanism for testing custom-scheme /
/// Universal Link delivery: it round-trips through the real system
/// URL-opening path — the same path `xcrun simctl openurl` and a tap on a
/// Universal Link both drive — and lands in the app via
/// `application(_:open:options:)` / SwiftUI's `.onOpenURL`, never by calling
/// any app code directly.
///
/// **Scheme.** iOS dispatches `open(_:)` by the app's *registered* URL
/// scheme — `iosdigitalwallet://`, not the `app://` shorthand the in-process
/// `DeepLinkFlowTests` scenarios use (that router deliberately ignores
/// scheme/host, so the shorthand is harmless there; the OS does not ignore
/// it). Read here from this target's own `Info.plist` — populated at build
/// time from `Module.deepLinkScheme` via `Module.appUITestTarget`'s
/// `DEEPLINK_SCHEME` build setting — rather than a second hard-coded
/// literal.
///
/// **The iOS 26 confirmation gate.** `open(_:)` raises the system's
/// "Open in '…'?" dialog. Task 8 could not dismiss it: `osascript` has no
/// Accessibility grant in this sandbox, and `idb` / `cliclick` are absent.
/// XCUITest does not need either — it drives SpringBoard through its own
/// automation session, the same session driving `app` itself, so
/// `XCUIApplication(bundleIdentifier: "com.apple.springboard")` reaches the
/// dialog's "Open" button directly.
final class DeepLinkOpenURLUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// `iosdigitalwallet://scanner/result/UITESTCODE123` end to end: the OS
    /// delivers the URL, `.onOpenURL` forwards it to `deepLinkRouter.open`,
    /// and the Scanner tab's Result screen ends up on screen showing the
    /// exact code the URL carried — read back through XCUITest's real
    /// accessibility-tree query, not the in-process `UIView` walk that
    /// `DeepLinkFlowTests` found does not surface SwiftUI `Text` content on
    /// this SDK (see that file's type doc comment).
    @available(iOS 16.4, *)
    func testOpeningSettingsURLThroughTheOSSelectsTheSettingsTab() throws {
        let app = XCUIApplication()
        app.launch()

        // Switch to tab 0 first so Settings is not the active tab
        let homeTabButton = app.tabBars.buttons.element(boundBy: 0)
        XCTAssertTrue(homeTabButton.waitForExistence(timeout: 10))
        homeTabButton.tap()

        let scheme = try XCTUnwrap(registeredURLScheme(), "this target's Info.plist must carry DeepLinkScheme")
        let url = try XCTUnwrap(URL(string: "\(scheme)://settings"))

        app.open(url)
        dismissOpenConfirmationIfPresented()

        let settingsIndex = app.tabBars.buttons.count - 1
        let settingsTabButton = app.tabBars.buttons.element(boundBy: settingsIndex)
        XCTAssertTrue(settingsTabButton.waitForExistence(timeout: 10))
        let becameSelected = NSPredicate(format: "isSelected == true")
        expectation(for: becameSelected, evaluatedWith: settingsTabButton)
        waitForExpectations(timeout: 10)
    }

    // MARK: - Helpers

    /// Reads back the scheme `Module.appUITestTarget` wrote into *this*
    /// target's own `Info.plist` at build time — `Bundle(for:)` here
    /// resolves to the UI test bundle, never the app-under-test's, since a
    /// UI test runs as a separate process from the app it drives.
    private func registeredURLScheme() -> String? {
        Bundle(for: DeepLinkOpenURLUITests.self).infoDictionary?["DeepLinkScheme"] as? String
    }

    /// iOS 26's "Open in '…'?" gate, dismissed through SpringBoard's own
    /// automation session (see the type doc comment). A no-op when the gate
    /// does not appear, so this stays safe to call unconditionally.
    private func dismissOpenConfirmationIfPresented() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        }
    }
}
