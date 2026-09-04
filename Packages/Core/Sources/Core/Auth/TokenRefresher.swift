/// Dependency-inversion seam for token refresh. `Network` depends on this
/// abstraction; the concrete adapter lives in the consumer's auth feature and is
/// wired at the composition root. `Sendable` — `Network` invokes it off the main
/// actor.
public protocol TokenRefresher: Sendable {
    /// Exchange `refreshToken` for a fresh access token — and, when the server
    /// rotates it, a new refresh token. Never throws: every outcome, success or
    /// failure, is modelled by `TokenRefreshResult`.
    func refresh(refreshToken: String) async -> TokenRefreshResult
}

/// Outcome of `TokenRefresher.refresh(refreshToken:)`.
public enum TokenRefreshResult: Sendable {
    /// A fresh access token, plus a rotated refresh token when the server issued
    /// one. `refreshToken == nil` means "keep the current refresh token".
    case success(accessToken: String, refreshToken: String?)
    /// The refresh produced no usable token; the associated `TokenRefreshFailure`
    /// says whether the caller must force a logout or merely fail the request.
    case failure(TokenRefreshFailure)
}

/// Why a token refresh failed, and therefore how the caller should react.
public enum TokenRefreshFailure: Sendable, Equatable {
    /// The refresh token is expired or revoked (the refresh endpoint returned
    /// `401`/`403`). The session is dead — force a logout.
    case invalidGrant
    /// A transport or `5xx` failure. The refresh may succeed later, so do **not**
    /// log out; the triggering request fails with its original error.
    case transient
}

/// Default `TokenRefresher`. Always fails with `.invalidGrant`, so an app that
/// has not wired a real adapter force-logs-out on the first `401` instead of
/// silently spinning. Replace it at the composition root.
public struct NoTokenRefresher: TokenRefresher {
    public init() {}

    public func refresh(refreshToken _: String) async -> TokenRefreshResult {
        .failure(.invalidGrant)
    }
}
