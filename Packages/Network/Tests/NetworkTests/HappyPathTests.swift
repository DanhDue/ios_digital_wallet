import Foundation
import XCTest
@testable import Network

/// Happy path + large-payload boundary.
final class HappyPathTests: StubbedClientTestCase {
    func testGetReturnsDecodedModelOn200WithValidJSON() async throws {
        let body = try JSONEncoder().encode(Widget(id: 7, name: "widget-7"))
        StubStore.shared.setHandler { _ in .response(status: 200, body: body) }

        let widget: Widget = try await makeClient().send(APIRequest(method: .get, path: "/widgets/7"))

        XCTAssertEqual(widget, Widget(id: 7, name: "widget-7"))
    }

    func test204NoContentEmptyBodyDecodesToEmptyResponse() async throws {
        StubStore.shared.setHandler { _ in .response(status: 204) }

        let result: EmptyResponse = try await makeClient().send(APIRequest(method: .delete, path: "/widgets/7"))

        XCTAssertEqual(result, EmptyResponse())
    }

    func testVeryLargeJSONArrayDecodesWithoutError() async throws {
        let items = (0 ..< 40000).map { Widget(id: $0, name: "row-\($0)") }
        let body = try JSONEncoder().encode(items)
        XCTAssertGreaterThan(body.count, 1_000_000, "fixture should exceed 1 MB")
        StubStore.shared.setHandler { _ in .response(status: 200, body: body) }

        let decoded: [Widget] = try await makeClient().send(APIRequest(method: .get, path: "/widgets"))

        XCTAssertEqual(decoded.count, 40000)
        XCTAssertEqual(decoded.last, Widget(id: 39999, name: "row-39999"))
    }

    func testResponseBodyIsValidJSONButMissingRequiredFieldThrowsDecoding() async {
        let body = Data(#"{"unexpected": true}"#.utf8)
        StubStore.shared.setHandler { _ in .response(status: 200, body: body) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as RequiredFieldModel
        } onError: { error in
            guard case NetworkError.decoding = error else {
                return XCTFail("expected .decoding, got \(error)")
            }
        }
    }

    func testResponseBodyIsNotJSONThrowsDecodingAndLogsRawSnippet() async {
        let body = Data("<html>nope</html>".utf8)
        StubStore.shared.setHandler { _ in .response(status: 200, body: body) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as Widget
        } onError: { error in
            guard case NetworkError.decoding = error else {
                return XCTFail("expected .decoding, got \(error)")
            }
        }

        XCTAssertTrue(
            logger.messages(level: "error").contains { $0.contains("<html>nope</html>") },
            "raw body snippet should be logged at error level"
        )
    }
}
