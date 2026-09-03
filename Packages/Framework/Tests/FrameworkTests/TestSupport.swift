import Combine
import Foundation
import XCTest
@testable import Framework

// MARK: - ViewState inspection (test-only; keeps the shipping enum free of Equatable)

extension ViewState {
    /// A stable discriminator so emission-order tests can assert `[String]`
    /// sequences without `STATE` / `Error` having to be `Equatable`.
    var tag: String {
        switch self {
        case .loading: "loading"
        case .error: "error"
        case .content: "content"
        }
    }

    var contentValue: STATE? {
        if case let .content(state) = self {
            return state
        }
        return nil
    }

    var errorValue: Error? {
        if case let .error(error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Recorder

/// Sinks a `Never`-failing publisher into an ordered array so tests can assert
/// the exact emission *sequence* (not just the terminal value). Lock-guarded and
/// `@unchecked Sendable` so the sink closure needs no actor hop under Swift 6
/// strict concurrency.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: some Publisher<Value, Never>) {
        cancellable = publisher.sink { [weak self] value in
            guard let self else { return }
            lock.lock()
            storage.append(value)
            lock.unlock()
        }
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        values.count
    }

    /// Detaches the sink. Emissions after this are not recorded.
    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - EffectProbe

/// A deterministic, sleep-free gate for async-effect tests. An effect calls
/// `await wait(id)` and suspends; the test drives progress with `release(id)` or
/// by cancelling the effect's `Task` (which makes `wait` throw
/// `CancellationError`). Every lifecycle transition is appended to `signals`,
/// and `waitUntil` lets a test await a specific one without polling or sleep.
actor EffectProbe {
    enum Signal: Equatable {
        case arrived(Int)
        case cancelled(Int)
        case completed(Int)
        case failed(Int)
    }

    private struct Waiter {
        let id: Int
        let predicate: (Signal) -> Bool
        let continuation: CheckedContinuation<Void, Never>
    }

    private(set) var signals: [Signal] = []
    private var gates: [Int: CheckedContinuation<Void, Error>] = [:]
    private var waiters: [Waiter] = []
    private var nextWaiterID = 0

    /// Suspends the calling effect until `release(id)` or Task cancellation.
    func wait(_ id: Int) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                gates[id] = continuation
                record(.arrived(id))
            }
        } onCancel: {
            Task { await self.failGate(id) }
        }
    }

    /// Lets a suspended effect proceed past its `wait(id)`.
    func release(_ id: Int) {
        gates.removeValue(forKey: id)?.resume()
    }

    /// Records a lifecycle signal emitted from inside an effect body.
    func note(_ signal: Signal) {
        record(signal)
    }

    /// Suspends until a signal satisfying `predicate` has been recorded
    /// (inspects the backlog first, so it never misses an earlier signal).
    /// Cancellation-aware: a cancelled waiter resumes and is removed, so a
    /// `raceTimeout` loser never leaks.
    func waitUntil(_ predicate: @escaping (Signal) -> Bool) async {
        if signals.contains(where: predicate) {
            return
        }
        let id = nextWaiterID
        nextWaiterID += 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                if Task.isCancelled {
                    continuation.resume()
                    return
                }
                waiters.append(Waiter(id: id, predicate: predicate, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    func waitUntil(_ signal: Signal) async {
        await waitUntil { $0 == signal }
    }

    private func cancelWaiter(_ id: Int) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume()
    }

    private func failGate(_ id: Int) {
        gates.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    private func record(_ signal: Signal) {
        signals.append(signal)
        waiters.removeAll { waiter in
            guard waiter.predicate(signal) else { return false }
            waiter.continuation.resume()
            return true
        }
    }
}

// MARK: - Race-safe timeout

/// Races `operation` against a deadline. Returns the operation's value, or `nil`
/// if the deadline wins. The deterministic gating lives in `EffectProbe`; this
/// only bounds *failure* so a broken implementation fails fast instead of
/// hanging the suite.
func raceTimeout<T: Sendable>(
    _ seconds: Double = 2.0,
    _ operation: @escaping @Sendable () async -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let first = await group.next().flatMap(\.self)
        group.cancelAll()
        return first
    }
}

/// Awaits a specific probe signal, failing the test (not hanging) on timeout.
/// A free function (not an `XCTestCase` method) so no non-`Sendable` test-case
/// `self` is sent across the isolation boundary under Swift 6 strict concurrency.
func expectSignal(
    _ probe: EffectProbe,
    _ signal: EffectProbe.Signal,
    timeout: Double = 2.0,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let reached = await raceTimeout(timeout) {
        await probe.waitUntil(signal)
        return true
    }
    XCTAssertNotNil(reached, "timed out waiting for probe signal \(signal)", file: file, line: line)
}

// MARK: - Fixtures: STATE / ACTION / EVENT

struct CountState: Equatable {
    var count: Int = 0
    var label: String = ""
}

enum CountAction: Equatable {
    case increment
    case load(Int)
    case ignored
    case failNonCancellation
    case spin
}

enum CountEvent: Equatable {
    case pinged
    case tagged(Int)
}

struct SampleError: Error, Equatable {
    let reason: String
}

// MARK: - CounterViewModel

/// Concrete `MviViewModel` used by every test. `onAction` records the action and
/// forwards to an injectable hook so each test can script its own reduction /
/// effect without a new subclass.
@MainActor
final class CounterViewModel: MviViewModel<CountState, CountAction, CountEvent> {
    private(set) var receivedActions: [CountAction] = []
    var onActionHook: ((CountAction) -> Void)?

    override func onAction(_ action: CountAction) {
        receivedActions.append(action)
        onActionHook?(action)
    }
}
