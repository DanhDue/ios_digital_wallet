import Foundation
import XCTest
@testable import Network

/// `APIRequest.urlRequest(for:)` — URL join, query encoding, headers, body.
final class APIRequestBuildTests: XCTestCase {
    private let base = FixedEnvironment(
        baseURL: requireURL("https://api.example.com"),
        defaultHeaders: ["Accept": "application/json", "X-Env": "test"]
    )

    func testEmptyPathTargetsBaseURL() throws {
        let request = try APIRequest(method: .get, path: "").urlRequest(for: base)
        XCTAssertEqual(request.url, requireURL("https://api.example.com"))
    }

    func testBaseURLWithAndWithoutTrailingSlashProduceTheSameURL() throws {
        let noSlash = FixedEnvironment(baseURL: requireURL("https://api.example.com"))
        let withSlash = FixedEnvironment(baseURL: requireURL("https://api.example.com/"))

        let fromNoSlash = try APIRequest(method: .get, path: "v1/things").urlRequest(for: noSlash)
        let fromWithSlash = try APIRequest(method: .get, path: "/v1/things").urlRequest(for: withSlash)

        XCTAssertEqual(fromNoSlash.url, requireURL("https://api.example.com/v1/things"))
        XCTAssertEqual(fromNoSlash.url, fromWithSlash.url)
    }

    func testQueryParamsWithReservedCharactersArePercentEncodedExactlyOnce() throws {
        let request = try APIRequest(
            method: .get,
            path: "/search",
            query: ["q": "a b&c=d/e", "page": "1"]
        ).urlRequest(for: base)

        let encoded = try XCTUnwrap(request.url?.query(percentEncoded: true))
        // sorted-key order: page then q
        XCTAssertEqual(encoded, "page=1&q=a%20b%26c%3Dd/e")
        // decoded exactly once -> original value back
        XCTAssertEqual(request.url?.query(percentEncoded: false), "page=1&q=a b&c=d/e")
        // no double-encoding of '%'
        XCTAssertFalse(encoded.contains("%25"))
    }

    func testPerRequestHeadersOverrideEnvironmentDefaults() throws {
        let request = try APIRequest(
            method: .get,
            path: "/x",
            headers: ["X-Env": "override", "X-Extra": "1"]
        ).urlRequest(for: base)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Env"), "override")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Extra"), "1")
    }

    func testBodyIsJSONEncodedWithContentTypeHeader() throws {
        let request = try APIRequest(
            method: .post,
            path: "/widgets",
            body: AnyEncodable(Widget(id: 1, name: "a"))
        ).urlRequest(for: base)

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let decoded = try JSONDecoder().decode(Widget.self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(decoded, Widget(id: 1, name: "a"))
    }

    func testMethodIsPropagated() throws {
        for method in [HTTPMethod.get, .post, .put, .delete, .patch] {
            let request = try APIRequest(method: method, path: "/x").urlRequest(for: base)
            XCTAssertEqual(request.httpMethod, method.rawValue)
        }
    }

    func testAppEnvironmentUsesPlaceholderHost() {
        for env in AppEnvironment.allCases {
            XCTAssertEqual(env.baseURL, requireURL("https://api.example.com"))
        }
    }

    // MARK: - authRequirement marker header

    func testAuthRequirementNoneSetsTheMarkerHeader() throws {
        let request = try APIRequest(method: .post, path: "/login", authRequirement: .none)
            .urlRequest(for: base)

        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Auth-Requirement"), "none")
    }

    func testAuthRequirementRequiredLeavesTheMarkerHeaderAbsent() throws {
        let request = try APIRequest(method: .get, path: "/me", authRequirement: .required)
            .urlRequest(for: base)

        XCTAssertNil(request.value(forHTTPHeaderField: "X-Auth-Requirement"))
    }

    func testDefaultAuthRequirementIsRequiredSoNoMarkerHeader() throws {
        let request = try APIRequest(method: .get, path: "/me").urlRequest(for: base)

        XCTAssertEqual(APIRequest(method: .get, path: "/me").authRequirement, .required)
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Auth-Requirement"))
    }
}
