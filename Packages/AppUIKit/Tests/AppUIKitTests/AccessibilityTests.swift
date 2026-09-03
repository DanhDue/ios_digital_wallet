import SwiftUI
import XCTest
@testable import AppUIKit

/// Accessibility contract for the components. SwiftUI does not expose applied
/// accessibility modifiers for inspection on the test host, so these assert the
/// strings / values the components are constructed with (and that the modifiers
/// are present in source).
@MainActor
final class AccessibilityTests: XCTestCase {
    func testAppButtonExposesItsTitleAsAccessibilityLabel() throws {
        let source = try PackageSources.contents(
            of: PackageSources.componentsDir
                .appendingPathComponent("Button")
                .appendingPathComponent("AppButton.swift")
        )
        XCTAssertTrue(
            source.contains(".accessibilityLabel(Text(title))"),
            "AppButton must expose its title as the accessibility label"
        )
    }

    func testAppLoadingViewIsAnAccessibilityElementLabelledLoading() throws {
        XCTAssertEqual(AppLoadingView().accessibilityLabelText, "Loading")
        let source = try PackageSources.contents(
            of: PackageSources.componentsDir
                .appendingPathComponent("State")
                .appendingPathComponent("AppLoadingView.swift")
        )
        XCTAssertTrue(source.contains(".accessibilityElement(children: .ignore)"))
        XCTAssertTrue(source.contains(".accessibilityLabel(Text(label))"))
    }

    func testAppTextFieldExposesItsPlaceholderAsAccessibilityLabel() throws {
        let source = try PackageSources.contents(
            of: PackageSources.componentsDir
                .appendingPathComponent("TextField")
                .appendingPathComponent("AppTextField.swift")
        )
        XCTAssertTrue(source.contains(".accessibilityLabel(Text(placeholder))"))
    }
}
