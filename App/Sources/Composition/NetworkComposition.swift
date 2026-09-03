import Core
import Foundation
import Network
import Platform

/// Builds the app's `URLSessionAPIClient` and wires the `AuthEventSink` seam
/// (Source Spec Changelog #8): a `401` surfaced by `Network` is translated —
/// here at the composition root, NOT inside `Network` — into a `UserLoggedOut`
/// event on the injected `AppEventBus`. This keeps `Network` a leaf on `Core`.
enum NetworkComposition {
    /// - Parameters:
    ///   - eventBus: the bus a `401` publishes `UserLoggedOut` onto.
    ///   - environment: API environment; defaults to `.debug` (the template ships
    ///     only a placeholder host).
    ///   - session: transport; injectable so tests can stub it with a
    ///     `URLProtocol`.
    ///   - logger: `Core.Logger` sink for transport / status errors.
    static func makeAPIClient(
        eventBus: AppEventBus,
        environment: any Environment = AppEnvironment.debug,
        session: URLSession = .shared,
        logger: any Core.Logger
    ) -> URLSessionAPIClient {
        URLSessionAPIClient(
            session: session,
            environment: environment,
            logger: logger,
            authEventSink: BusAuthEventSink(eventBus: eventBus)
        )
    }
}

/// The concrete `AuthEventSink`. `Network` calls `onUnauthorized()` off the main
/// actor exactly once per `401`; this republishes it as an `AppEvent`.
///
/// `@unchecked Sendable`: the only stored value is the `Sendable` `AppEventBus`,
/// never reassigned.
final class BusAuthEventSink: AuthEventSink, @unchecked Sendable {
    private let eventBus: AppEventBus

    init(eventBus: AppEventBus) {
        self.eventBus = eventBus
    }

    func onUnauthorized() {
        eventBus.publish(UserLoggedOut())
    }
}
