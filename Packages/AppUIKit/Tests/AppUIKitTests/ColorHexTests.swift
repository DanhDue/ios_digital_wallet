import SwiftUI
import XCTest
@testable import AppUIKit

/// The `Color(hex:)` parse matrix — equivalence classes + boundary lengths.
final class ColorHexTests: XCTestCase {
    // MARK: valid forms

    func testParsesHashRRGGBB() {
        XCTAssertNotNil(Color(hex: "#FF8800"))
    }

    func testParsesBareRRGGBB() {
        XCTAssertNotNil(Color(hex: "FF8800"))
    }

    func testParsesHashRGBShortForm() {
        XCTAssertNotNil(Color(hex: "#F80"))
    }

    func testParsesBareRGBShortForm() {
        XCTAssertNotNil(Color(hex: "abc"))
    }

    func testShortFormEqualsExpandedLongForm() {
        XCTAssertEqual(Color(hex: "#F80"), Color(hex: "#FF8800"))
        XCTAssertEqual(Color(hex: "abc"), Color(hex: "aabbcc"))
    }

    func testParsesBlackAndWhiteExtremes() {
        XCTAssertEqual(Color(hex: "#000000"), Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
        XCTAssertEqual(Color(hex: "#FFFFFF"), Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1))
    }

    func testChannelDecodingIsCorrect() {
        // #336699 -> 51/255, 102/255, 153/255
        XCTAssertEqual(
            Color(hex: "#336699"),
            Color(.sRGB, red: 51.0 / 255.0, green: 102.0 / 255.0, blue: 153.0 / 255.0, opacity: 1)
        )
    }

    func testParsingIsCaseInsensitive() {
        XCTAssertEqual(Color(hex: "#ffaa00"), Color(hex: "#FFAA00"))
    }

    // MARK: invalid forms -> nil

    func testReturnsNilForNonHexString() {
        XCTAssertNil(Color(hex: "xyz"))
    }

    func testReturnsNilForEmptyString() {
        XCTAssertNil(Color(hex: ""))
        XCTAssertNil(Color(hex: "#"))
    }

    func testReturnsNilForWrongLength() {
        XCTAssertNil(Color(hex: "#FF")) // 2
        XCTAssertNil(Color(hex: "#FFFF")) // 4
        XCTAssertNil(Color(hex: "#FFFFF")) // 5
        XCTAssertNil(Color(hex: "#FFFFFFF")) // 7
        XCTAssertNil(Color(hex: "#FFFFFFFF")) // 8 (RRGGBBAA unsupported)
        XCTAssertNil(Color(hex: "#1234567890")) // 10 (too long)
    }

    func testReturnsNilWhenHexHasNonHexCharacters() {
        XCTAssertNil(Color(hex: "#GG0011"))
        XCTAssertNil(Color(hex: "12 34 56"))
        XCTAssertNil(Color(hex: "#12-34-56"))
    }
}
