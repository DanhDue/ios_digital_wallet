import Combine

/// Process-wide broadcast channel for ``AppEvent``s.
///
/// Backed by a `PassthroughSubject` (replay 0, fire-and-forget). An instance is
/// injected at the composition root; ``shared`` exists only for publishers that
/// cannot receive injection (network interceptor, lifecycle observer) — mirrors
/// the Android design.
///
/// `@unchecked Sendable`: the sole stored property is a `PassthroughSubject`,
/// whose `send(_:)` and subscribe are internally serialised by Combine and which
/// is never reassigned, so `publish(_:)` is safe to call from any thread without
/// an extra lock.
public final class AppEventBus: @unchecked Sendable {
    /// Convenience instance for non-injectable publishers. Prefer injection.
    public static let shared = AppEventBus()

    private let subject = PassthroughSubject<any AppEvent, Never>()

    public init() {}

    /// Broadcast `event` to current subscribers. Safe to call from any thread.
    public func publish(_ event: any AppEvent) {
        subject.send(event)
    }

    /// A publisher of every subsequently-published event of concrete type `T`,
    /// in publish order. Events of other types are filtered out.
    public func on<T: AppEvent>(_: T.Type) -> AnyPublisher<T, Never> {
        subject
            .compactMap { $0 as? T }
            .eraseToAnyPublisher()
    }
}
