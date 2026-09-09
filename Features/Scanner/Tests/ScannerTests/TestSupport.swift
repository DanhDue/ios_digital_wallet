import Combine
import Core
import Foundation
import Framework
import XCTest
@testable import Scanner

// MARK: - ViewState inspection (keeps the shipping enum free of Equatable)

extension ViewState {
    /// Stable discriminator for exact-sequence assertions.
    var tag: String {
        switch self {
        case .loading: "loading"
        case .error: "error"
        case .content: "content"
        }
    }
}

// MARK: - Combine recorder

/// Sinks a `Never`-failing publisher into an ordered array so tests can assert
/// the exact emission *sequence*. Lock-guarded / `@unchecked Sendable`.
/// Subscribe BEFORE the action under test.
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

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - Spy repository

/// Counts calls and lets a test script the result of `fetch`.
@MainActor
final class SpyScannerRepository: ScannerRepository {
    private(set) var fetchCallCount = 0
    var fetchResult: DataState<ScannerEntity> = .success(.stub)

    func fetch() async -> DataState<ScannerEntity> {
        fetchCallCount += 1
        return fetchResult
    }
}

// MARK: - Test Extension for ScannerViewModel

extension ScannerViewModel {
    convenience init(repository: any ScannerRepository) {
        self.init(getScannerData: GetScannerDataUseCase(repository: repository))
    }
}

// MARK: - Async helper

/// Polls `predicate` (cheap sleeps, no busy-spin) until it holds or `timeout`
/// elapses.
@MainActor
func poll(
    timeout: TimeInterval = 2,
    _ predicate: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}
