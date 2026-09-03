import Core
import Foundation
import XCTest
@testable import Network

/// Status / transport failures map to the expected `NetworkError` and
/// `AppError.code`, and the body is logged at error level for `5xx`.
final class NetworkErrorMappingTests: StubbedClientTestCase {
    func testTransportTimeoutMapsToTimeoutThenAppErrorCodeTimeout() async {
        StubStore.shared.setHandler { _ in .failure(URLError(.timedOut)) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as Widget
        } onError: { error in
            guard case NetworkError.timeout = error else {
                return XCTFail("expected .timeout, got \(error)")
            }
            XCTAssertEqual((error as? NetworkError)?.asAppError().code, "timeout")
        }
    }

    func testGenericTransportFailureMapsToTransport() async {
        StubStore.shared.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as Widget
        } onError: { error in
            guard case NetworkError.transport = error else {
                return XCTFail("expected .transport, got \(error)")
            }
            XCTAssertEqual((error as? NetworkError)?.asAppError().code, "transport")
        }
    }

    func testHTTP500MapsToServerAndLogsBodyAtErrorLevel() async {
        StubStore.shared.setHandler { _ in .response(status: 500, body: Data("internal boom".utf8)) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as Widget
        } onError: { error in
            guard case let NetworkError.server(code) = error else {
                return XCTFail("expected .server, got \(error)")
            }
            XCTAssertEqual(code, 500)
            XCTAssertEqual((error as? NetworkError)?.asAppError().code, "server")
        }

        XCTAssertTrue(
            logger.messages(level: "error").contains { $0.contains("internal boom") },
            "5xx body should be logged at error level"
        )
    }

    func testHTTP404MapsToClient() async {
        StubStore.shared.setHandler { _ in .response(status: 404, body: Data("nope".utf8)) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as Widget
        } onError: { error in
            guard case let NetworkError.client(code) = error else {
                return XCTFail("expected .client, got \(error)")
            }
            XCTAssertEqual(code, 404)
            XCTAssertEqual((error as? NetworkError)?.asAppError().code, "client")
        }
    }

    func testMissingRequiredFieldMapsToDecodingAppErrorCode() async {
        StubStore.shared.setHandler { _ in .response(status: 200, body: Data(#"{"nope":1}"#.utf8)) }

        await assertThrowsAsync {
            _ = try await self.makeClient().send(APIRequest(method: .get, path: "/x")) as RequiredFieldModel
        } onError: { error in
            guard case NetworkError.decoding = error else {
                return XCTFail("expected .decoding, got \(error)")
            }
            XCTAssertEqual((error as? NetworkError)?.asAppError().code, "decoding")
        }
    }

    func testNonHTTPResponseMapsToInvalidResponse() {
        XCTAssertEqual(NetworkError.invalidResponse.asAppError().code, "invalid_response")
    }

    func testUnauthorizedMapsToAppErrorCodeUnauthorized() {
        XCTAssertEqual(NetworkError.unauthorized.asAppError().code, "unauthorized")
    }

    func testAppErrorCarriesUnderlyingDescriptionForWrappedErrors() {
        let underlying = URLError(.cannotFindHost)
        let mapped = NetworkError.transport(underlying).asAppError()
        XCTAssertNotNil(mapped.underlying)
    }
}
