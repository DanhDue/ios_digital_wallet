import Foundation

/// The host + base headers a request is resolved against. `Sendable` because
/// `URLSessionAPIClient` reads it off the main actor while building a request.
public protocol Environment: Sendable {
    /// Scheme + host (+ optional base path). A trailing slash is tolerated;
    /// `APIRequest` normalises the join so `base` / `base/` behave identically.
    var baseURL: URL { get }
    /// Headers merged into every request (a per-request header of the same name
    /// wins).
    var defaultHeaders: [String: String] { get }
}
