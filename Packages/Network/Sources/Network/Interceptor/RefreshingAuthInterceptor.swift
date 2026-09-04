import Core
import Foundation

/// The authed-client interceptor: attaches the bearer on the way out and, on a
/// `401`, runs a single-flight token refresh and resends the request exactly
/// once. Replaces `AuthTokenInterceptor` at the composition root whenever a
/// real `TokenRefresher` is wired; `AuthTokenInterceptor` stays for header-only
/// (no-refresh) use.
///
/// A plain `final class`: every stored dependency is `Sendable` and there is no
/// mutable state here — the single-flight guarantee lives in the `actor`
/// `RefreshCoordinator`.
public final class RefreshingAuthInterceptor: RequestInterceptor {
    private let session: SessionManaging
    private let refresher: TokenRefresher
    private let coordinator: RefreshCoordinator
    private let authEventSink: AuthEventSink?
    private let refreshEndpoint: RefreshTokenEndpoint

    public init(
        session: SessionManaging,
        refresher: TokenRefresher,
        coordinator: RefreshCoordinator,
        authEventSink: AuthEventSink? = nil,
        refreshEndpoint: RefreshTokenEndpoint
    ) {
        self.session = session
        self.refresher = refresher
        self.coordinator = coordinator
        self.authEventSink = authEventSink
        self.refreshEndpoint = refreshEndpoint
    }

    // MARK: - adapt

    /// Attach `Authorization: Bearer <accessToken>` unless the request opts out
    /// (`X-Auth-Requirement: none`, which is then stripped) or targets the
    /// refresh endpoint (which carries its own credential in the body).
    public func adapt(_ request: URLRequest) async -> URLRequest {
        var mutated = request
        if mutated.value(forHTTPHeaderField: AuthHeader.requirement) == AuthHeader.requirementNone {
            mutated.setValue(nil, forHTTPHeaderField: AuthHeader.requirement)
            return mutated
        }
        if let url = request.url, refreshEndpoint.matches(url) {
            return request
        }
        guard let token = session.accessToken, !token.isEmpty else {
            return request
        }
        mutated.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return mutated
    }

    // MARK: - didReceive

    public func didReceive(_: HTTPURLResponse) {}

    // MARK: - retry

    /// The force-logout decision ladder for a `401` (spec §4.4). `.transport` is
    /// out of scope and always declines.
    public func retry(_ request: URLRequest, dueTo reason: RetryReason) async -> RetryDecision {
        guard case .unauthorized = reason else {
            return .doNotRetry
        }

        // Case 2 (misconfiguration guard): a 401 from the refresh endpoint
        // itself means the refresh token is dead — never loop a refresh through
        // it. Refresh normally runs via `makeBareAPIClient()`, which has no
        // `RefreshingAuthInterceptor`; this branch only fires on misrouting.
        if let url = request.url, refreshEndpoint.matches(url) {
            session.clear()
            authEventSink?.onUnauthorized(reason: .refreshFailed)
            return .doNotRetry
        }

        // Case 1: the one permitted resend already carried a fresh bearer and
        // still got a 401 — the session is unrecoverable.
        if request.value(forHTTPHeaderField: AuthHeader.retry) == AuthHeader.retryValue {
            session.clear()
            authEventSink?.onUnauthorized(reason: .retryStillUnauthorized)
            return .doNotRetry
        }

        // Case 3: a 401 but nothing on the device to refresh with.
        guard session.refreshToken != nil else {
            session.clear()
            authEventSink?.onUnauthorized(reason: .missingRefreshToken)
            return .doNotRetry
        }

        // Single-flight refresh: concurrent 401s coalesce onto one refresh call.
        do {
            let newAccess = try await coordinator.refreshedAccessToken { [session, refresher] in
                guard let refreshToken = session.refreshToken else {
                    throw RefreshError.missingRefreshToken
                }
                switch await refresher.refresh(refreshToken: refreshToken) {
                case let .success(access, refresh):
                    session.update(accessToken: access, refreshToken: refresh)
                    return access
                case .failure(.invalidGrant):
                    throw RefreshError.invalidGrant
                case .failure(.transient):
                    throw RefreshError.transient
                }
            }
            return .retry(rebuilt(request, bearer: newAccess))
        } catch RefreshError.invalidGrant, RefreshError.missingRefreshToken {
            // Case 2: dead session — an invalid grant, or (rare) the refresh
            // token was cleared between the guard above and the refresh call.
            // Both mean the same thing to the caller: force a logout.
            session.clear()
            authEventSink?.onUnauthorized(reason: .refreshFailed)
            return .doNotRetry
        } catch {
            // RefreshError.transient: a flaky network during refresh must NOT
            // end the session — no `clear()`, no `onUnauthorized`. The
            // triggering request fails with its original
            // `NetworkError.unauthorized`; a later request can refresh.
            //
            // Task cancellation is surfaced by `URLSessionAPIClient`'s
            // `Task.checkCancellation()` before the resend, never remapped here
            // (`retry` is non-throwing by protocol).
            return .doNotRetry
        }
    }

    // MARK: - Helpers

    /// Rebuild `request` for the single permitted resend: overwrite the stale
    /// `Authorization` header with `bearer` and stamp `X-Auth-Retry: 1`. The
    /// client resends this verbatim — `send` does not re-run `adapt` — so the
    /// fresh bearer must already be on it.
    private func rebuilt(_ request: URLRequest, bearer: String) -> URLRequest {
        var mutated = request
        mutated.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        mutated.setValue(AuthHeader.retryValue, forHTTPHeaderField: AuthHeader.retry)
        return mutated
    }
}
