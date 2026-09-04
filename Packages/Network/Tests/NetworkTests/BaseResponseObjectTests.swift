import Foundation
import XCTest
@testable import Network

final class BaseResponseObjectTests: StubbedClientTestCase {
    // MARK: - Test fixture

    private struct Item: Decodable, Sendable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - Scenario 1: Full envelope decode

    func testDecodesFullEnvelopeWithAllFieldsPopulated() throws {
        let json = """
        {
            "data": {"id": 1, "name": "widget-1"},
            "message": "ok",
            "status": 200
        }
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("could not encode JSON")
            return
        }
        let decoder = JSONDecoder()

        let result: BaseResponseObject<Item> = try decoder.decode(
            BaseResponseObject<Item>.self,
            from: data
        )

        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?.id, 1)
        XCTAssertEqual(result.data?.name, "widget-1")
        XCTAssertEqual(result.message, "ok")
        XCTAssertEqual(result.status, 200)
    }

    // MARK: - Scenario 2: Partial keys (no message/status)

    func testDecodesWithoutMessageAndStatusKeysLeavingThemNil() throws {
        let json = """
        {
            "data": {"id": 1, "name": "widget-1"}
        }
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("could not encode JSON")
            return
        }
        let decoder = JSONDecoder()

        let result: BaseResponseObject<Item> = try decoder.decode(
            BaseResponseObject<Item>.self,
            from: data
        )

        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?.id, 1)
        XCTAssertEqual(result.data?.name, "widget-1")
        XCTAssertNil(result.message)
        XCTAssertNil(result.status)
    }

    // MARK: - Scenario 3: Without data key

    func testDecodesWithoutDataKeyLeavingDataNil() throws {
        let json = """
        {
            "message": "nope",
            "status": 404
        }
        """
        guard let data = json.data(using: .utf8) else {
            XCTFail("could not encode JSON")
            return
        }
        let decoder = JSONDecoder()

        let result: BaseResponseObject<Item> = try decoder.decode(
            BaseResponseObject<Item>.self,
            from: data
        )

        XCTAssertNil(result.data)
        XCTAssertEqual(result.message, "nope")
        XCTAssertEqual(result.status, 404)
    }

    // MARK: - Scenario 4: Empty object

    func testDecodesEmptyObjectWithAllFieldsNil() throws {
        let json = "{}"
        guard let data = json.data(using: .utf8) else {
            XCTFail("could not encode JSON")
            return
        }
        let decoder = JSONDecoder()

        let result: BaseResponseObject<Item> = try decoder.decode(
            BaseResponseObject<Item>.self,
            from: data
        )

        XCTAssertNil(result.data)
        XCTAssertNil(result.message)
        XCTAssertNil(result.status)
    }

    // MARK: - Scenario 5: End-to-end with URLSessionAPIClient

    func testURLSessionAPIClientSendReturningBaseResponseObjectWorks() async throws {
        let json = """
        {
            "data": {"id": 42, "name": "test-item"},
            "message": "success",
            "status": 200
        }
        """
        guard let body = json.data(using: .utf8) else {
            XCTFail("could not encode JSON")
            return
        }
        StubStore.shared.setHandler { _ in .response(status: 200, body: body) }

        let result: BaseResponseObject<Item> = try await makeClient()
            .send(APIRequest(method: .get, path: "/items/42"))

        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?.id, 42)
        XCTAssertEqual(result.data?.name, "test-item")
        XCTAssertEqual(result.message, "success")
        XCTAssertEqual(result.status, 200)
    }
}
