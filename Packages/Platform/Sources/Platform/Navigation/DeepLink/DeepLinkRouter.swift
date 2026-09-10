import Core
import Foundation

/// The engine (Source Spec §4.6): owns the pattern table assembled from
/// every registered `RouteProvider.deepLinks`, resolves a `URL` to a route
/// stack, asks the optional `DeepLinkGuard` whether that stack may be
/// navigated to, asks the optional `TabResolver` which tab it lands in, and
/// drives `AppRouter`. A link a guard could not yet allow is held — exactly
/// one, no TTL — until `drainPending()` retries it.
///
/// **Governing principle (Source Spec §6):** junk input from outside the app
/// is ordinary input. Nothing crashes, nothing throws, and no failure path
/// mutates `AppRouter` state — every failure is logged once through the
/// injected `Core.Logger` and reported through the return value, so the host
/// decides whether to react. **`.opened` must always mean something actually
/// moved** — never a false success reported because a bad tab index was
/// silently swallowed by `AppRouter`'s own no-op-on-bad-index mutators.
@MainActor
public final class DeepLinkRouter {
    /// One link parked because a guard redirected it with `retainPending:
    /// true`. Holds exactly one entry — a newer link always supersedes an
    /// older one, matching the "go here now" semantics of a deep link. No
    /// TTL (YAGNI).
    private struct PendingLink {
        let stack: [any AppRoute]
        let requiresAuth: Bool
    }

    private let router: AppRouter
    private let linkGuard: (any DeepLinkGuard)?
    private let tabResolver: (any TabResolver)?
    private let logger: (any Core.Logger)?

    /// The resolution table, in registration order. First match wins — the
    /// same chain-of-responsibility contract `AppRouter.destination(for:)`
    /// already uses.
    private var table: [DeepLinkRoute] = []

    private var pending: PendingLink?

    /// - Parameters:
    ///   - router: the `AppRouter` this engine drives.
    ///   - linkGuard: the host's allow / redirect / deny seam. `nil` means
    ///     allow-all. Declared with the external label `guard` to match the
    ///     spec's call-site shape.
    ///   - tabResolver: the host's tab-placement seam. `nil` means "always
    ///     use the currently selected tab".
    ///   - logger: where failure paths log. `nil` is a silent no-op sink.
    public init(
        router: AppRouter,
        guard linkGuard: (any DeepLinkGuard)? = nil,
        tabResolver: (any TabResolver)? = nil,
        logger: (any Core.Logger)? = nil
    ) {
        self.router = router
        self.linkGuard = linkGuard
        self.tabResolver = tabResolver
        self.logger = logger
    }

    /// Loads `provider.deepLinks` into the resolution table, in
    /// registration order.
    public func register(_ provider: any RouteProvider) {
        table.append(contentsOf: provider.deepLinks)
    }

    /// Normalises `url`, resolves it against the registration-ordered
    /// pattern table, and — on a match — asks the guard, then navigates.
    @discardableResult
    public func open(_ url: URL) -> DeepLinkOutcome {
        guard let link = DeepLink(url: url) else {
            log("open(_:) — URL did not normalise into a DeepLink: \(url)")
            return .unmatched
        }
        guard let match = firstMatch(for: link) else {
            log("open(_:) — no registered pattern matched: \(url)")
            return .unmatched
        }
        let stack = match.route.build(match.params)
        guard !stack.isEmpty else {
            log("open(_:) — matched route's build(_:) returned an empty stack: \(url)")
            return .unmatched
        }
        return resolve(stack: stack, requiresAuth: match.route.requiresAuth)
    }

    /// Re-attempts the single stored pending link, e.g. after the host
    /// observes a sign-in event. A no-op when nothing is pending.
    public func drainPending() {
        guard let pendingLink = pending else { return }
        pending = nil
        resolve(stack: pendingLink.stack, requiresAuth: pendingLink.requiresAuth)
    }

    // MARK: - Resolution

    private func firstMatch(for link: DeepLink) -> (route: DeepLinkRoute, params: DeepLinkParams)? {
        for route in table {
            if let params = route.pattern.match(link) {
                return (route, params)
            }
        }
        return nil
    }

    // MARK: - Gating + navigation

    /// Consults the guard (allow-all when absent) and acts on its decision.
    /// Shared by `open(_:)` and `drainPending()` so both go through
    /// identical gating, navigation, and pending-management logic.
    @discardableResult
    private func resolve(stack: [any AppRoute], requiresAuth: Bool) -> DeepLinkOutcome {
        switch linkGuard?.evaluate(stack, requiresAuth: requiresAuth) ?? .allow {
        case .allow:
            // `navigate(stack:)` itself logs why, when it returns `false` —
            // an unusable tab must never be reported as `.opened`.
            guard navigate(stack: stack) else {
                pending = nil
                return .denied
            }
            pending = nil
            return .opened

        case let .redirect(redirectStack, retainPending):
            return handleRedirect(
                to: redirectStack,
                retainPending: retainPending,
                originalStack: stack,
                requiresAuth: requiresAuth
            )

        case .deny:
            pending = nil
            log("resolve(stack:requiresAuth:) — guard denied a \(stack.count)-route stack")
            return .denied
        }
    }

    /// Evaluates the redirect target **once**, never recursively, so a
    /// guard that redirects its own redirect target cannot loop the router
    /// forever. Anything other than `.allow` for the target becomes
    /// `.denied` — see `GuardDecision.redirect`'s "reachable without auth"
    /// invariant.
    ///
    /// The outcome stays `.pendingGuard` once the guard has allowed the
    /// redirect target, even if `navigate(stack:)` then finds nothing it
    /// can actually push (an empty `redirectStack`, or no usable tab) — a
    /// host-configured redirect target failing is a narrower, deliberately
    /// unchanged decision from before this fix; `navigate(stack:)` still
    /// logs so the failure is never silent.
    private func handleRedirect(
        to redirectStack: [any AppRoute],
        retainPending: Bool,
        originalStack: [any AppRoute],
        requiresAuth: Bool
    ) -> DeepLinkOutcome {
        guard case .allow = linkGuard?.evaluate(redirectStack, requiresAuth: false) ?? .allow else {
            pending = nil
            log("handleRedirect(to:...) — redirect target itself was not allowed; denying instead of looping")
            return .denied
        }

        pending = retainPending ? PendingLink(stack: originalStack, requiresAuth: requiresAuth) : nil
        navigate(stack: redirectStack)
        return .pendingGuard
    }

    /// Resolves a usable tab for `stack` and pushes it there — dropping a
    /// leading route that is that tab's own root only when the tab that
    /// claimed the root is the tab actually used — then reports whether
    /// anything could move.
    ///
    /// `isTabRoot` is a claim about **one specific tab**. If that tab was
    /// rejected as unusable, the claim is rejected with it: dropping the
    /// first route regardless would silently discard a route that is not
    /// the root of the tab the stack actually lands on.
    ///
    /// Returns `false` — logging why — for an empty `stack`, or when no
    /// candidate tab (the resolver's placement, then `router.selectedTab`)
    /// indexes into `router.tabPaths`. The caller decides what outcome that
    /// implies.
    @discardableResult
    private func navigate(stack: [any AppRoute]) -> Bool {
        guard let first = stack.first else {
            log("navigate(stack:) — called with an empty stack; nothing to push")
            return false
        }

        let placement = tabResolver?.placement(for: first)
        guard let tab = usableTab(preferring: placement?.tab) else {
            log(
                "navigate(stack:) — no usable tab for a \(router.tabPaths.count)-tab router "
                    + "(placement \(String(describing: placement?.tab)), selectedTab "
                    + "\(router.selectedTab)); nothing moved"
            )
            return false
        }

        var toPush = stack
        if placement?.isTabRoot == true, tab == placement?.tab {
            toPush.removeFirst()
        }

        router.switchTab(tab)
        router.popToRoot(inTab: tab)
        for route in toPush {
            router.navigate(to: route, inTab: tab)
        }
        return true
    }

    /// A tab is usable only if it indexes into `router.tabPaths`. Tries
    /// `candidate` (the resolver's placement) first — logging once if one
    /// was offered but is out of range — then falls back to
    /// `router.selectedTab`, itself validated: `AppRouter.init` does not
    /// clamp `initialTab` and explicitly supports `tabCount: 0`, so the
    /// current tab can itself be unusable. Returns `nil` when neither
    /// candidate is usable — a degenerate router configuration the caller
    /// must treat as failure, never a silent `.opened`.
    private func usableTab(preferring candidate: Int?) -> Int? {
        if let candidate {
            if router.tabPaths.indices.contains(candidate) {
                return candidate
            }
            log(
                "usableTab(preferring:) — TabResolver returned out-of-range tab \(candidate); "
                    + "falling back to selectedTab \(router.selectedTab)"
            )
        }
        return router.tabPaths.indices.contains(router.selectedTab) ? router.selectedTab : nil
    }

    // MARK: - Logging

    /// `file`/`function`/`line` default to the **call site**, not this
    /// helper's own body — without the defaults, every entry would report
    /// `function: "log"` and this method's own line for every call site.
    private func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        logger?.error("[DeepLinkRouter] \(message)", file: file, function: function, line: line)
    }
}

/// The result of `DeepLinkRouter.open(_:)`.
public enum DeepLinkOutcome: Equatable {
    /// The stack was pushed exactly as resolved.
    case opened

    /// A guard redirected the request; a redirect stack was pushed instead
    /// and, when the guard asked to retain it, the original link is now
    /// pending replay via `drainPending()`.
    case pendingGuard

    /// A guard denied the request, its redirect target itself was not
    /// allowed, or no usable tab existed to navigate an otherwise-allowed
    /// stack to. No `AppRouter` state changed.
    case denied

    /// `DeepLink(url:)` failed, no pattern matched, or the matched route's
    /// `build(_:)` returned an empty stack. No `AppRouter` state changed.
    case unmatched
}
