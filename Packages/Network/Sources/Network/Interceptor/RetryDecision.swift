import Foundation

/// Why `URLSessionAPIClient` is asking an interceptor whether to resend a
/// request. `transport` is scaffolded for a future reachability-driven
/// interceptor; `send` only ever asks with `.unauthorized` today.
public enum RetryReason: Sendable {
    /// A non-2xx `401` response came back for the request.
    case unauthorized(HTTPURLResponse)
    /// The request failed before any response (DNS, offline, TLS, …).
    case transport(Error)
}

/// An interceptor's answer to `retry(_:dueTo:)`. `retry` carries the exact
/// `URLRequest` the client should resend — already re-adapted by the
/// interceptor that returns it; the client sends it verbatim.
public enum RetryDecision: Sendable {
    /// Do not resend; let the original failure surface.
    case doNotRetry
    /// Resend this request exactly once.
    case retry(URLRequest)
}

/// In-process signalling headers shared by `APIRequest` and the auth
/// interceptors. They never travel on the wire: the interceptor that consumes
/// one strips it inside `adapt` / before returning a `.retry` request.
enum AuthHeader {
    /// Set by `APIRequest.urlRequest(for:)` when `authRequirement == .none`;
    /// read and stripped by `AuthTokenInterceptor` (and, in Task 4,
    /// `RefreshingAuthInterceptor`).
    static let requirement = "X-Auth-Requirement"
    /// Value of `requirement` that opts a request out of bearer injection.
    static let requirementNone = "none"
    /// Marks a request as the single permitted resend after a refresh. Owned by
    /// the interceptor that returns `.retry`; `send` never sets it itself.
    static let retry = "X-Auth-Retry"
    /// Value of `retry` on a resent request.
    static let retryValue = "1"
}
