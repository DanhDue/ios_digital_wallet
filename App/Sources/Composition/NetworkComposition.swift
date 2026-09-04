import Core
import Foundation
import Network
import Platform

/// Builds the app's `URLSessionAPIClient`s and wires the `AuthEventSink` seam
/// (Source Spec Changelog #8): a `401` surfaced by `Network` is translated —
/// here at the composition root, NOT inside `Network` — into a `UserLoggedOut`
/// event on the injected `AppEventBus`. This keeps `Network` a leaf on `Core`.
enum NetworkComposition {
    /// The app's authed, refresh-capable client: `RefreshingAuthInterceptor`
    /// (single-flight refresh + force-logout on a dead session) followed by
    /// `LoggingInterceptor`.
    ///
    /// - Parameters:
    ///   - eventBus: the bus a force-logout publishes `UserLoggedOut` onto.
    ///   - environment: API environment; defaults to `.debug` (the template ships
    ///     only a placeholder host).
    ///   - session: transport; injectable so tests can stub it with a
    ///     `URLProtocol`.
    ///   - logger: `Core.Logger` sink for transport / status errors.
    ///   - sessionManager: token storage `RefreshingAuthInterceptor` reads and
    ///     mutates. Defaults to a fresh in-memory-only `SessionManager()`.
    ///   - tokenRefresher: the refresh strategy. Defaults to `NoTokenRefresher()`
    ///     — the honest default for a domain-neutral template: a real `401`
    ///     force-logs-out instead of silently spinning.
    ///   - refreshEndpoint: identifies the refresh call so it never gets a
    ///     bearer and a `401` from it is never itself treated as a refresh
    ///     trigger. Defaults to a placeholder `"auth/refresh"` suffix.
    static func makeAPIClient(
        eventBus: AppEventBus,
        environment: any Environment = AppEnvironment.debug,
        session: URLSession = .shared,
        logger: any Core.Logger,
        sessionManager: any SessionManaging = SessionManager(),
        tokenRefresher: any TokenRefresher = NoTokenRefresher(),
        refreshEndpoint: RefreshTokenEndpoint = RefreshTokenEndpoint(pathSuffix: "auth/refresh")
    ) -> URLSessionAPIClient {
        URLSessionAPIClient(
            session: session,
            interceptors: [
                RefreshingAuthInterceptor(
                    session: sessionManager,
                    refresher: tokenRefresher,
                    coordinator: RefreshCoordinator(),
                    authEventSink: BusAuthEventSink(eventBus: eventBus),
                    refreshEndpoint: refreshEndpoint
                ),
                LoggingInterceptor(logger: logger),
            ],
            environment: environment,
            logger: logger
        )
    }

    /// A bare, unauthenticated client carrying **only** `LoggingInterceptor` —
    /// no `RefreshingAuthInterceptor`, no `AuthTokenInterceptor`.
    ///
    /// A `TokenRefresher` adapter MUST call the refresh endpoint through this
    /// client, never through `makeAPIClient`'s authed client: routing the
    /// refresh call through the authed client would let a `401` from the
    /// refresh call itself re-enter `RefreshingAuthInterceptor.retry`, which
    /// would try to refresh again — infinite recursion. This function has no
    /// `eventBus` / `authEventSink` / `tokenRefresher` parameter at all, so it
    /// is structurally incapable of notifying a sink.
    ///
    /// - Parameters:
    ///   - environment: API environment; defaults to `.debug`.
    ///   - session: transport; injectable so tests can stub it with a
    ///     `URLProtocol`.
    ///   - logger: `Core.Logger` sink for transport / status errors.
    static func makeBareAPIClient(
        environment: any Environment = AppEnvironment.debug,
        session: URLSession = .shared,
        logger: any Core.Logger
    ) -> URLSessionAPIClient {
        URLSessionAPIClient(
            session: session,
            interceptors: [LoggingInterceptor(logger: logger)],
            environment: environment,
            logger: logger
        )
    }
}

/// The concrete `AuthEventSink`. `Network` calls `onUnauthorized(reason:)` off
/// the main actor exactly once per force-logout; this republishes it as an
/// `AppEvent`.
///
/// `@unchecked Sendable`: the only stored value is the `Sendable` `AppEventBus`,
/// never reassigned.
final class BusAuthEventSink: AuthEventSink, @unchecked Sendable {
    private let eventBus: AppEventBus

    init(eventBus: AppEventBus) {
        self.eventBus = eventBus
    }

    func onUnauthorized(reason: LogoutReason) {
        eventBus.publish(UserLoggedOut(reason: reason))
    }
}
