import Combine
import Core
import Foundation
import Platform

/// Builds the app's `DeepLinkRouter` (Source Spec §4.8): installs the host's
/// `DeepLinkGuard` (`SessionDeepLinkGuard`) and `TabResolver`
/// (`ShellTabResolver`) seams, then registers every already-built
/// `RouteProvider` onto it, in order.
///
/// Deliberately outside the `// app:route-providers:begin/end` marker region
/// in `AppComposition.swift`: that region already accumulates every feature's
/// provider into `providers`. Registering the finished array here, once,
/// after the loop, means a future `mason make ios_mvi_feature` needs zero
/// additional edits outside the region it already owns — this file's
/// `for provider in providers` loop absorbs any new entry automatically.
@MainActor
enum DeepLinkComposition {
    static func makeRouter(
        router: AppRouter,
        providers: [any RouteProvider],
        deepLinkGuard: any DeepLinkGuard,
        tabResolver: any TabResolver,
        logger: (any Core.Logger)? = nil
    ) -> DeepLinkRouter {
        let deepLinkRouter = DeepLinkRouter(
            router: router,
            guard: deepLinkGuard,
            tabResolver: tabResolver,
            logger: logger
        )
        for provider in providers {
            deepLinkRouter.register(provider)
        }
        return deepLinkRouter
    }
}

/// The host's authentication seam (Source Spec §4.8): reads
/// `Core.SessionManaging.accessToken` synchronously. `.allow` when
/// `requiresAuth` is `false` or a token is present; otherwise
/// `.redirect(to: redirectTo, retainPending: true)` when a redirect stack was
/// configured, `.deny` when it was not.
///
/// **The template passes an empty `redirectTo`** — `Features/` ships only
/// `Scanner` and `Settings`, no authentication feature, so there is nowhere to
/// redirect to. A consuming project supplies its own login route in one line.
/// This is the same wired-but-unexercised posture `AppComposition` already
/// documents for `sessionManager` and `apiClient`.
struct SessionDeepLinkGuard: DeepLinkGuard {
    private let session: any SessionManaging
    private let redirectTo: [any AppRoute]

    init(session: any SessionManaging, redirectTo: [any AppRoute]) {
        self.session = session
        self.redirectTo = redirectTo
    }

    func evaluate(_: [any AppRoute], requiresAuth: Bool) -> GuardDecision {
        guard requiresAuth else { return .allow }
        guard session.accessToken == nil else { return .allow }
        guard !redirectTo.isEmpty else { return .deny }
        return .redirect(to: redirectTo, retainPending: true)
    }
}

/// The host's tab-placement seam (Source Spec §4.8): the single place the
/// shell's tab layout is restated. Mirrors
/// `Packages/Shell/Sources/Shell/ShellView.swift`'s hard-coded layout exactly
/// — tab 0 is a Shell-owned stub with no `AppRoute`, tab 1 is
/// `AppRoutes.ScannerRoot`, tab 2 is `AppRoutes.SettingsRoot`. `Shell` cannot
/// own this map itself: it must stay feature-blind (invariant R1), so the map
/// lives here, in the one module allowed to know both the shell's layout and
/// the features' routes.
///
/// `Platform.TabPlacement` is qualified because `SwiftUI.TabPlacement`
/// (iOS 18+) collides by name in any file that imports both `SwiftUI` and
/// `Platform`.
struct ShellTabResolver: TabResolver {
    func placement(for route: any AppRoute) -> Platform.TabPlacement? {
        switch route {
        // app:tab-resolver-scanner:begin
        case is AppRoutes.ScannerRoot:
            Platform.TabPlacement(tab: 1, isTabRoot: true)
        // app:tab-resolver-scanner:end
        case is AppRoutes.SettingsRoot:
            Platform.TabPlacement(tab: 2, isTabRoot: true)
        default:
            nil
        }
    }
}

/// Subscribes to `UserLoggedIn` and replays whatever `DeepLinkRouter` is
/// holding pending (Source Spec §4.8 / §4.9) — the completion of the "guard
/// redirected the link, the user signed in" loop. Owns the `AnyCancellable`
/// so its lifetime is tied to this observer's; `AppComposition` keeps one
/// alive for the process lifetime, exactly as it does for `LifecycleObserver`.
///
/// `.receive(on: DispatchQueue.main)`: `AppEventBus.publish(_:)` is documented
/// safe to call from any thread, so delivery is explicitly redispatched onto
/// the main thread — the actual executor `DeepLinkRouter` (a `@MainActor`
/// type) requires — rather than relying on the publishing thread happening to
/// already be the main one.
@MainActor
final class DeepLinkReplayObserver {
    private var cancellable: AnyCancellable?

    init(eventBus: AppEventBus, deepLinkRouter: DeepLinkRouter) {
        cancellable = eventBus.on(UserLoggedIn.self)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                deepLinkRouter.drainPending()
            }
    }
}
