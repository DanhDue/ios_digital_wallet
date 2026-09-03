import SwiftUI
import XCTest
@testable import AppUIKit

/// Semantic color tokens: documented exact hex per appearance, light ≠ dark, and
/// `color(for:)` always resolves.
final class AppColorTests: XCTestCase {
    /// The documented palette. Kept here as the spec the implementation must meet.
    private let documented: [AppColor: (light: String, dark: String)] = [
        .primary: ("#0B5FFF", "#4C8DFF"),
        .secondary: ("#5A6472", "#9AA4B2"),
        .destructive: ("#D7263D", "#FF5A5F"),
        .background: ("#FFFFFF", "#0B0B0F"),
        .surface: ("#F2F3F5", "#1C1C22"),
        .textPrimary: ("#11181C", "#F5F7FA"),
        .textSecondary: ("#5A6472", "#A7B0BA"),
    ]

    func testEveryTokenResolvesToItsDocumentedHexInLightAndDark() {
        for token in AppColor.allCases {
            guard let expected = documented[token] else {
                return XCTFail("no documented hex for \(token.rawValue)")
            }
            XCTAssertEqual(token.lightHex, expected.light, "\(token.rawValue) light")
            XCTAssertEqual(token.darkHex, expected.dark, "\(token.rawValue) dark")
        }
    }

    func testPrimaryResolvesToDocumentedHexInLightMode() {
        XCTAssertEqual(AppColor.primary.hex(for: .light), "#0B5FFF")
    }

    func testPrimaryResolvesToADifferentHexInDarkMode() {
        XCTAssertEqual(AppColor.primary.hex(for: .dark), "#4C8DFF")
        XCTAssertNotEqual(AppColor.primary.hex(for: .light), AppColor.primary.hex(for: .dark))
    }

    func testEverySemanticTokenDiffersBetweenLightAndDark() {
        for token in AppColor.allCases {
            XCTAssertNotEqual(
                token.lightHex,
                token.darkHex,
                "\(token.rawValue) must have distinct light/dark values"
            )
        }
    }

    func testHexForSchemeSelectsTheRightVariant() {
        for token in AppColor.allCases {
            XCTAssertEqual(token.hex(for: .light), token.lightHex)
            XCTAssertEqual(token.hex(for: .dark), token.darkHex)
        }
    }

    func testEveryDocumentedHexIsParseable() {
        for token in AppColor.allCases {
            XCTAssertNotNil(Color(hex: token.lightHex), "\(token.rawValue) light hex must parse")
            XCTAssertNotNil(Color(hex: token.darkHex), "\(token.rawValue) dark hex must parse")
        }
    }

    func testColorForSchemeAlwaysResolves() {
        for token in AppColor.allCases {
            _ = token.color(for: .light)
            _ = token.color(for: .dark)
        }
    }

    func testSemanticColorConveniencesAreConstructible() {
        _ = Color.appPrimary
        _ = Color.appSecondary
        _ = Color.appDestructive
        _ = Color.appBackground
        _ = Color.appSurface
        _ = Color.appTextPrimary
        _ = Color.appTextSecondary
    }
}
