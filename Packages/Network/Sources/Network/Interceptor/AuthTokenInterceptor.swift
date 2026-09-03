import Core
import Foundation

/// Adds `Authorization: Bearer <token>` when the injected `SessionManaging`
/// currently holds a token; leaves the request untouched when it does not.
public final class AuthTokenInterceptor: RequestInterceptor {
    private let session: SessionManaging

    public init(session: SessionManaging) {
        self.session = session
    }

    public func adapt(_ request: URLRequest) async -> URLRequest {
        guard let token = session.accessToken, !token.isEmpty else {
            return request
        }
        var mutated = request
        mutated.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutated
    }

    public func didReceive(_: HTTPURLResponse) {}
}
