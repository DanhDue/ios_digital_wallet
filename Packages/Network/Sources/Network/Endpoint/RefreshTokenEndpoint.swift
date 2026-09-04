import Foundation

/// Identifies the refresh path so `RefreshingAuthInterceptor` can (a) skip
/// bearer injection for it — the refresh call carries its own credential in the
/// body — and (b) treat a `401` from it as a dead session rather than a trigger
/// to refresh again.
///
/// No URL is hard-coded: the composition root supplies the path suffix that its
/// `TokenRefresher` adapter actually calls (e.g. `"auth/refresh"`).
public struct RefreshTokenEndpoint: Sendable {
    public let pathSuffix: String

    public init(pathSuffix: String) {
        self.pathSuffix = pathSuffix
    }

    /// `true` when `url`'s path ends with `pathSuffix`. Host and query are
    /// ignored.
    public func matches(_ url: URL) -> Bool {
        url.path.hasSuffix(pathSuffix)
    }
}
