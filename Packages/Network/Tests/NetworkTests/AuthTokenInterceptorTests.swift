import Core
import Foundation
import XCTest
@testable import Network

/// `AuthTokenInterceptor` toggles the `Authorization` header off the injected
/// `SessionManaging` state.
final class AuthTokenInterceptorTests: XCTestCase {
    private func request() -> URLRequest {
        URLRequest(url: requireURL("https://api.example.com/me"))
    }

    func testAddsBearerHeaderWhenSessionHasToken() async {
        let session = SessionManager(accessToken: "abc123")
        let interceptor = AuthTokenInterceptor(session: session)

        let adapted = await interceptor.adapt(request())

        XCTAssertEqual(adapted.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
    }

    func testAddsNoAuthorizationHeaderWhenTokenIsNil() async {
        let session = SessionManager(accessToken: nil)
        let interceptor = AuthTokenInterceptor(session: session)

        let adapted = await interceptor.adapt(request())

        XCTAssertNil(adapted.value(forHTTPHeaderField: "Authorization"))
    }

    func testReflectsTokenClearedAtRuntime() async {
        let session = SessionManager(accessToken: "abc123")
        let interceptor = AuthTokenInterceptor(session: session)
        session.clear()

        let adapted = await interceptor.adapt(request())

        XCTAssertNil(adapted.value(forHTTPHeaderField: "Authorization"))
    }

    // MARK: - Public-endpoint whitelist (authRequirement == .none)

    func testAuthRequirementNoneSkipsBearerAndStripsTheMarkerHeader() async {
        let session = SessionManager(accessToken: "abc123")
        let interceptor = AuthTokenInterceptor(session: session)
        var incoming = request()
        incoming.setValue(AuthHeader.requirementNone, forHTTPHeaderField: AuthHeader.requirement)

        let adapted = await interceptor.adapt(incoming)

        XCTAssertNil(adapted.value(forHTTPHeaderField: "Authorization"), "no bearer for a public endpoint")
        XCTAssertNil(adapted.value(forHTTPHeaderField: AuthHeader.requirement), "marker stripped before the wire")
    }

    func testAuthRequirementRequiredWithASessionTokenAttachesTheBearer() async {
        let session = SessionManager(accessToken: "abc123")
        let interceptor = AuthTokenInterceptor(session: session)

        // A `.required` request carries no marker header at all.
        let adapted = await interceptor.adapt(request())

        XCTAssertEqual(adapted.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
        XCTAssertNil(adapted.value(forHTTPHeaderField: AuthHeader.requirement))
    }

    // MARK: - retry(_:dueTo:)

    func testRetryOnUnauthorizedNotifiesSinkOnceWithUnauthorizedAndDeclinesToRetry() async throws {
        let sink = SpyAuthEventSink()
        let interceptor = AuthTokenInterceptor(session: SessionManager(accessToken: "abc123"), authEventSink: sink)
        let response = try XCTUnwrap(HTTPURLResponse(
            url: requireURL("https://api.example.com/me"),
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        ))

        let decision = await interceptor.retry(request(), dueTo: .unauthorized(response))

        guard case .doNotRetry = decision else {
            return XCTFail("expected .doNotRetry, got \(decision)")
        }
        XCTAssertEqual(sink.reasons, [.unauthorized])
    }

    func testRetryOnTransportReturnsDoNotRetryAndDoesNotNotify() async {
        let sink = SpyAuthEventSink()
        let interceptor = AuthTokenInterceptor(session: SessionManager(accessToken: nil), authEventSink: sink)

        let decision = await interceptor.retry(request(), dueTo: .transport(URLError(.notConnectedToInternet)))

        guard case .doNotRetry = decision else {
            return XCTFail("expected .doNotRetry, got \(decision)")
        }
        XCTAssertEqual(sink.callCount, 0)
    }

    func testEndToEndThroughClientSetsHeaderOnTheWire() async throws {
        StubStore.shared.reset()
        defer { StubStore.shared.reset() }
        let session = StubStore.makeSession()
        defer { session.invalidateAndCancel() }
        StubStore.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer live-token")
            return .response(status: 200, body: Data("{\"id\":1,\"name\":\"a\"}".utf8))
        }
        let client = URLSessionAPIClient(
            session: session,
            interceptors: [AuthTokenInterceptor(session: SessionManager(accessToken: "live-token"))],
            environment: FixedEnvironment(baseURL: requireURL("https://api.example.com")),
            logger: SpyLogger()
        )

        _ = try await client.send(APIRequest(method: .get, path: "/me")) as Widget
    }
}
