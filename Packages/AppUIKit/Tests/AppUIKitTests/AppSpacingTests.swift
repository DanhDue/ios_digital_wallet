import CoreGraphics
import XCTest
@testable import AppUIKit

/// Boundary / equivalence: the spacing scale must be the exact 8pt-grid values.
final class AppSpacingTests: XCTestCase {
    func testSpacingConstantsHaveExact8ptGridValues() {
        XCTAssertEqual(AppSpacing.xs, 4)
        XCTAssertEqual(AppSpacing.sm, 8)
        XCTAssertEqual(AppSpacing.md, 16)
        XCTAssertEqual(AppSpacing.lg, 24)
        XCTAssertEqual(AppSpacing.xl, 32)
    }

    func testSpacingScaleIsStrictlyIncreasing() {
        let scale: [CGFloat] = [AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl]
        XCTAssertEqual(scale, scale.sorted())
        XCTAssertEqual(Set(scale).count, scale.count)
    }

    func testSpacingValuesAreCGFloat() {
        XCTAssertTrue(type(of: AppSpacing.md) == CGFloat.self)
    }
}
