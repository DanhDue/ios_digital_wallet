import XCTest

/// Scanner-specific UI tests driven through the OS.
/// Extracted from DeepLinkOpenURLUITests.swift so UI tests are mode-aware.
final class ScannerTabUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @available(iOS 16.4, *)
    func testOpeningARealURLThroughTheOSNavigatesToTheResultScreen() throws {
        let app = XCUIApplication()
        app.launch()

        let scheme = try XCTUnwrap(registeredURLScheme(), "this target's Info.plist must carry DeepLinkScheme")
        let url = try XCTUnwrap(URL(string: "\(scheme)://scanner/result/UITESTCODE123"))

        app.open(url)
        dismissOpenConfirmationIfPresented()

        let codeText = app.staticTexts["scanner.result.code"]
        XCTAssertTrue(
            codeText.waitForExistence(timeout: 10),
            "expected 'scanner.result.code' to appear in the view hierarchy after deep link"
        )
        XCTAssertEqual(codeText.label, "UITESTCODE123")
    }

    @available(iOS 16.4, *)
    func testOpeningARealScannerURLThroughTheOSSelectsTheScannerTab() throws {
        let app = XCUIApplication()
        app.launch()

        let scheme = try XCTUnwrap(registeredURLScheme(), "this target's Info.plist must carry DeepLinkScheme")
        let url = try XCTUnwrap(URL(string: "\(scheme)://scanner"))

        app.open(url)
        dismissOpenConfirmationIfPresented()

        let scannerTabButton = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(scannerTabButton.waitForExistence(timeout: 10))
        let becameSelected = NSPredicate(format: "isSelected == true")
        expectation(for: becameSelected, evaluatedWith: scannerTabButton)
        waitForExpectations(timeout: 10)
    }

    // MARK: - Helpers

    private func registeredURLScheme() -> String? {
        Bundle(for: ScannerTabUITests.self).infoDictionary?["DeepLinkScheme"] as? String
    }

    private func dismissOpenConfirmationIfPresented() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 5) {
            openButton.tap()
        }
    }
}
