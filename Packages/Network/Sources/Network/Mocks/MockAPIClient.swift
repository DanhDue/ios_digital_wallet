import Core
import Foundation

/// Failure surfaced by `MockAPIClient` when its queue is empty or the queued
/// value is not the type the caller asked for.
public enum MockAPIClientError: Error, Equatable, LocalizedError {
    /// The result queue was exhausted.
    case noMoreResponses
    /// A queued success value did not match the requested `Decodable` type.
    case typeMismatch(expected: String, actual: String)

    public var errorDescription: String? {
        switch self {
        case .noMoreResponses:
            "MockAPIClient: no more responses"
        case let .typeMismatch(expected, actual):
            "MockAPIClient: queued value is \(actual), caller asked for \(expected)"
        }
    }
}

/// A FIFO-queue `APIClient` test double. Enqueue successes / errors in the order
/// calls will consume them; an empty queue throws `MockAPIClientError`.
/// `artificialDelay` sleeps before each response so Feature tests can reproduce
/// races deterministically (Source Spec §9A). `@unchecked Sendable` — an
/// `NSLock` guards all mutable state.
public final class MockAPIClient: APIClient, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [Result<Any, Error>] = []
    private var delay: Duration = .zero

    public init() {}

    /// Sleep applied before serving each queued response.
    public var artificialDelay: Duration {
        get { lock.withLock { delay } }
        set { lock.withLock { delay = newValue } }
    }

    /// Number of responses still queued.
    public var remaining: Int {
        lock.withLock { queue.count }
    }

    /// Queue a success value. It is returned as-is when a `send` call requests a
    /// matching `T`.
    public func enqueueSuccess(_ value: some Any) {
        lock.withLock { queue.append(.success(value)) }
    }

    /// Queue an error. The matching `send` call rethrows it.
    public func enqueueError(_ error: Error) {
        lock.withLock { queue.append(.failure(error)) }
    }

    public func send<T: Decodable>(_: APIRequest) async throws -> T {
        let pause = artificialDelay
        if pause > .zero {
            try await Task.sleep(for: pause)
        }
        let next: Result<Any, Error>? = lock.withLock {
            queue.isEmpty ? nil : queue.removeFirst()
        }
        guard let next else {
            throw MockAPIClientError.noMoreResponses
        }
        switch next {
        case let .success(value):
            guard let typed = value as? T else {
                throw MockAPIClientError.typeMismatch(
                    expected: String(describing: T.self),
                    actual: String(describing: type(of: value))
                )
            }
            return typed
        case let .failure(error):
            throw error
        }
    }
}
