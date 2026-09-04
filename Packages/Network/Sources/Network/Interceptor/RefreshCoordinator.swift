/// Guarantees exactly one in-flight token refresh. The first caller starts the
/// work; every concurrent caller awaits the *same* `Task` and receives its
/// result (value or error). Once that task resolves the in-flight slot is
/// cleared — in actor isolation, via `defer` — so the next wave of `401`s
/// starts a fresh refresh rather than reusing a stale one.
///
/// This is the Swift-6-native equivalent of a "refreshing" mutex + waiter
/// queue: `actor` isolation makes the check-and-store atomic without a lock.
public actor RefreshCoordinator {
    private var inFlight: Task<String, Error>?

    public init() {}

    /// Return a fresh access token. `perform` is the real refresh call, supplied
    /// by `RefreshingAuthInterceptor` closing over its `TokenRefresher` and
    /// `SessionManaging`. The first caller runs `perform`; concurrent callers
    /// join the same task. Rethrows whatever `perform` throws (a `RefreshError`)
    /// to *every* awaiter.
    public func refreshedAccessToken(
        perform: @Sendable @escaping () async throws -> String
    ) async throws -> String {
        if let inFlight {
            return try await inFlight.value
        }
        let task = Task { try await perform() }
        inFlight = task
        // Runs on the actor once this call unwinds (success or throw), so a
        // later 401 wave starts a brand-new refresh.
        defer { inFlight = nil }
        return try await task.value
    }
}

/// Why a refresh performed by `RefreshCoordinator` failed. Maps 1:1 to
/// `TokenRefreshFailure` plus the "no token to refresh with" case that
/// `RefreshingAuthInterceptor` detects inside `perform`.
public enum RefreshError: Error, Equatable {
    /// The refresh token is expired or revoked — the session is dead.
    case invalidGrant
    /// There was no refresh token to send (cleared out mid-flight).
    case missingRefreshToken
    /// A transport / `5xx` failure — the refresh may succeed later; do not log out.
    case transient
}
