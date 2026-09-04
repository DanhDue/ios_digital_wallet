import Core
import Foundation

/// Adds `Authorization: Bearer <token>` when the injected `SessionManaging`
/// currently holds a token; leaves the request untouched when it does not.
///
/// Honours the public-endpoint whitelist: a request carrying
/// `AuthHeader.requirement: none` gets no bearer, and the marker is stripped
/// before the request goes out. With no refresh interceptor installed this is
/// also where a bare `401` is reported — `retry(_:dueTo: .unauthorized)`
/// notifies the optional `AuthEventSink` once, then declines to resend.
public final class AuthTokenInterceptor: RequestInterceptor {
    private let session: SessionManaging
    private let authEventSink: AuthEventSink?

    public init(session: SessionManaging, authEventSink: AuthEventSink? = nil) {
        self.session = session
        self.authEventSink = authEventSink
    }

    public func adapt(_ request: URLRequest) async -> URLRequest {
        var mutated = request
        if mutated.value(forHTTPHeaderField: AuthHeader.requirement) == AuthHeader.requirementNone {
            mutated.setValue(nil, forHTTPHeaderField: AuthHeader.requirement)
            return mutated
        }
        guard let token = session.accessToken, !token.isEmpty else {
            return request
        }
        mutated.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutated
    }

    public func didReceive(_: HTTPURLResponse) {}

    public func retry(_: URLRequest, dueTo reason: RetryReason) async -> RetryDecision {
        switch reason {
        case .unauthorized:
            authEventSink?.onUnauthorized(reason: .unauthorized)
        case .transport:
            break
        }
        return .doNotRetry
    }
}
