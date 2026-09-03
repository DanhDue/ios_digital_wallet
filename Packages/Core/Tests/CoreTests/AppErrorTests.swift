import XCTest
@testable import Core

final class AppErrorTests: XCTestCase {
    func testUnderlyingDefaultsToNil() {
        let error = AppError(code: "c", message: "m")
        XCTAssertNil(error.underlying)
    }

    func testEqualWhenAllFieldsMatch() {
        let lhs = AppError(code: "c", message: "m", underlying: "u")
        let rhs = AppError(code: "c", message: "m", underlying: "u")
        XCTAssertEqual(lhs, rhs)
    }

    func testUnequalWhenAnyFieldDiffers() {
        let base = AppError(code: "c", message: "m", underlying: "u")
        XCTAssertNotEqual(base, AppError(code: "x", message: "m", underlying: "u"))
        XCTAssertNotEqual(base, AppError(code: "c", message: "x", underlying: "u"))
        XCTAssertNotEqual(base, AppError(code: "c", message: "m", underlying: nil))
    }

    func testIsThrowableAsError() {
        func throwing() throws {
            throw AppError(code: "c", message: "m")
        }
        XCTAssertThrowsError(try throwing()) { error in
            XCTAssertEqual(error as? AppError, AppError(code: "c", message: "m"))
        }
    }
}
