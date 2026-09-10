import Foundation

/// The host's authentication/authorization seam (Source Spec §4.5): decides
/// whether a matched deep-link stack may be navigated to. `Platform` never
/// learns what "auth" means — the guard receives only a `Bool` the feature
/// declared (`DeepLinkRoute.requiresAuth`) and a stack of opaque routes, and
/// answers a yes / no / redirect question (invariant R1).
///
/// **Synchronous by design.** `Core.SessionManaging.accessToken` is a
/// synchronous, `NSLock`-guarded read, so `DeepLinkRouter.open(_:)` never
/// needs to go `async` to consult this seam — the whole engine stays
/// testable without expectations.
///
/// **Optional at `DeepLinkRouter.init`.** `nil` means allow-all: a consumer
/// that gates nothing gets working deep links with zero configuration.
@MainActor
public protocol DeepLinkGuard {
    /// - Parameters:
    ///   - stack: the parent-to-child routes `DeepLinkRoute.build` produced,
    ///     in the exact order they would be pushed.
    ///   - requiresAuth: the matched `DeepLinkRoute.requiresAuth` value,
    ///     verbatim.
    func evaluate(_ stack: [any AppRoute], requiresAuth: Bool) -> GuardDecision
}

/// The guard's answer for one `DeepLinkGuard.evaluate(_:requiresAuth:)` call.
public enum GuardDecision {
    /// Proceed exactly as resolved.
    case allow

    /// Do not proceed; instead navigate to `to` (e.g. a sign-in screen).
    /// When `retainPending` is `true`, the original stack is stored so a
    /// later `DeepLinkRouter.drainPending()` can retry it once the guard's
    /// answer may have changed (e.g. after sign-in).
    ///
    /// `to` is itself evaluated by this same guard exactly once, with
    /// `requiresAuth: false` — **a redirect target must be reachable
    /// without authentication.** A guard that answers anything other than
    /// `.allow` for its own redirect target causes the router to report
    /// `.denied` rather than loop forever chasing further redirects.
    case redirect(to: [any AppRoute], retainPending: Bool)

    /// Do not proceed. Any previously pending link is cleared.
    case deny
}
