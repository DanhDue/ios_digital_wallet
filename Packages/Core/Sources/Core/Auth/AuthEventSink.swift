/// Why a session was terminated. Passed to `AuthEventSink.onUnauthorized(reason:)`
/// so the composition root can tell an ordinary sign-out from a dead session and
/// surface the right diagnostics.
public enum LogoutReason: Sendable, Equatable {
    /// A plain `401` with no refresh attempted — the back-compat default.
    case unauthorized
    /// The refresh endpoint rejected the refresh token.
    case refreshFailed
    /// The request was retried once with a fresh token and still got a `401`.
    case retryStillUnauthorized
    /// A `401` arrived but there is no refresh token on the device.
    case missingRefreshToken
}

/// Dependency-inversion seam for a 401. `Network` reports an unauthorized
/// response without importing `Platform`; the composition root wires the
/// concrete sink into `AppEventBus`. `Sendable` — `Network` invokes it off the
/// main actor.
public protocol AuthEventSink: AnyObject, Sendable {
    /// The session is no longer valid; `reason` says why.
    func onUnauthorized(reason: LogoutReason)
}

public extension AuthEventSink {
    /// Back-compat overload — existing parameterless call-sites keep working and
    /// report `.unauthorized`.
    func onUnauthorized() {
        onUnauthorized(reason: .unauthorized)
    }
}
