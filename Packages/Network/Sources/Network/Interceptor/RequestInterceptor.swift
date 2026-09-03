import Foundation

/// A hook around every request. `adapt` runs before the request is sent (in
/// registration order); `didReceive` runs after headers come back (same order).
/// `Sendable` — the client holds `[RequestInterceptor]` and calls them off the
/// main actor.
public protocol RequestInterceptor: Sendable {
    /// Return the request to actually send. Called in registration order; each
    /// interceptor sees the previous one's output.
    func adapt(_ request: URLRequest) async -> URLRequest
    /// Observe the response headers. Called in registration order. Never invoked
    /// when the request is cancelled or fails at the transport layer.
    func didReceive(_ response: HTTPURLResponse)
}
