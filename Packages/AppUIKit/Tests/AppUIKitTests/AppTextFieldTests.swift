import SwiftUI
import XCTest
@testable import AppUIKit

@MainActor
final class AppTextFieldTests: XCTestCase {
    func testEmptyBindingShowsPlaceholder() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = AppTextField("Email", text: binding)
        XCTAssertTrue(field.showsPlaceholder)
    }

    func testNonEmptyBindingHidesPlaceholder() {
        var text = "a@b.com"
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = AppTextField("Email", text: binding)
        XCTAssertFalse(field.showsPlaceholder)
    }

    func testWhitespaceOnlyValueIsStillNonEmptyForPlaceholderPurposes() {
        var text = " "
        let binding = Binding(get: { text }, set: { text = $0 })
        let field = AppTextField("Email", text: binding)
        XCTAssertFalse(field.showsPlaceholder)
    }

    func testPlainAndSecureFieldsRender() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        assertRenders(AppTextField("Email", text: binding))
        assertRenders(AppTextField("Password", text: binding, isSecure: true))
    }

    func testRendersWithPrefilledValue() {
        var text = "prefilled"
        let binding = Binding(get: { text }, set: { text = $0 })
        assertRenders(AppTextField("Email", text: binding))
    }
}
