import XCTest
@testable import Core

final class DataStateTests: XCTestCase {
    private let sampleError = AppError(code: "e", message: "boom")

    // MARK: map — happy path

    func testMapTransformsSuccessValue() {
        let result = DataState<Int>.success(42).map { $0 * 2 }
        XCTAssertEqual(result.successValue, 84)
    }

    func testMapIdentityKeepsValue() {
        let result = DataState<Int>.success(7).map(\.self)
        XCTAssertEqual(result.successValue, 7)
    }

    // MARK: map — boundary values

    func testMapCarriesIntMinAndIntMax() {
        XCTAssertEqual(DataState<Int>.success(Int.min).map(\.self).successValue, Int.min)
        XCTAssertEqual(DataState<Int>.success(Int.max).map(\.self).successValue, Int.max)
    }

    // MARK: map — passthrough cases (transform must NOT run)

    func testMapOnErrorPropagatesErrorAndDoesNotCallTransform() {
        var called = false
        let result = DataState<Int>.error(sampleError).map { value -> Int in
            called = true
            return value
        }
        XCTAssertEqual(result.errorValue, sampleError)
        XCTAssertFalse(called)
    }

    func testMapOnLoadingStaysLoadingAndDoesNotCallTransform() {
        var called = false
        let result = DataState<Int>.loading.map { value -> Int in
            called = true
            return value
        }
        XCTAssertTrue(result.isLoading)
        XCTAssertFalse(called)
    }

    // MARK: flatMap

    func testFlatMapSuccessToSuccess() {
        let result = DataState<Int>.success(3).flatMap { DataState<String>.success("v\($0)") }
        XCTAssertEqual(result.successValue, "v3")
    }

    func testFlatMapSuccessToError() {
        let result = DataState<Int>.success(3).flatMap { _ in DataState<String>.error(self.sampleError) }
        XCTAssertEqual(result.errorValue, sampleError)
    }

    func testFlatMapOnErrorPropagatesAndDoesNotCallTransform() {
        var called = false
        let result = DataState<Int>.error(sampleError).flatMap { _ -> DataState<String> in
            called = true
            return .loading
        }
        XCTAssertEqual(result.errorValue, sampleError)
        XCTAssertFalse(called)
    }

    func testFlatMapOnLoadingStaysLoadingAndDoesNotCallTransform() {
        var called = false
        let result = DataState<Int>.loading.flatMap { _ -> DataState<String> in
            called = true
            return .success("x")
        }
        XCTAssertTrue(result.isLoading)
        XCTAssertFalse(called)
    }
}
