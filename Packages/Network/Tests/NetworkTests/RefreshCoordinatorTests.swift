import Foundation
import XCTest
@testable import Network

/// `RefreshCoordinator` guarantees exactly one in-flight refresh: concurrent
/// callers await the same `Task`; the slot is cleared (in actor isolation) once
/// it resolves so a later 401 wave starts a fresh refresh; a throwing `perform`
/// reaches every awaiter.
final class RefreshCoordinatorTests: XCTestCase {
    func testSingleCallerRunsPerformExactlyOnce() async throws {
        let coordinator = RefreshCoordinator()
        let calls = LockedCounter()

        let token = try await coordinator.refreshedAccessToken {
            calls.increment()
            return "A2"
        }

        XCTAssertEqual(token, "A2")
        XCTAssertEqual(calls.increment(), 2, "perform ran once — this increment is the 2nd")
    }

    func testTenConcurrentCallersCoalesceOntoOneRefresh() async throws {
        let coordinator = RefreshCoordinator()
        let calls = LockedCounter()
        let perform: @Sendable () async throws -> String = {
            calls.increment()
            try? await Task.sleep(for: .milliseconds(40))
            return "A2"
        }

        let tokens = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0 ..< 10 {
                group.addTask { try await coordinator.refreshedAccessToken(perform: perform) }
            }
            var collected: [String] = []
            for try await value in group {
                collected.append(value)
            }
            return collected
        }

        XCTAssertEqual(tokens, Array(repeating: "A2", count: 10))
        XCTAssertEqual(calls.increment(), 2, "perform invoked exactly once for the whole wave")
    }

    func testInFlightSlotIsClearedAfterResolution() async throws {
        let coordinator = RefreshCoordinator()
        let calls = LockedCounter()

        let first = try await coordinator.refreshedAccessToken {
            "A\(calls.increment())"
        }
        let second = try await coordinator.refreshedAccessToken {
            "A\(calls.increment())"
        }

        XCTAssertEqual(first, "A1")
        XCTAssertEqual(second, "A2", "the slot cleared, so a later call runs perform again")
    }

    func testThrowingPerformPropagatesToEveryAwaiter() async {
        let coordinator = RefreshCoordinator()
        let calls = LockedCounter()
        let perform: @Sendable () async throws -> String = {
            calls.increment()
            try? await Task.sleep(for: .milliseconds(40))
            throw RefreshError.transient
        }

        let errors = await withTaskGroup(of: Error?.self) { group -> [Error?] in
            for _ in 0 ..< 10 {
                group.addTask {
                    do {
                        _ = try await coordinator.refreshedAccessToken(perform: perform)
                        return nil
                    } catch {
                        return error
                    }
                }
            }
            var collected: [Error?] = []
            for await value in group {
                collected.append(value)
            }
            return collected
        }

        XCTAssertEqual(errors.count, 10)
        for error in errors {
            XCTAssertEqual(error as? RefreshError, .transient)
        }
        XCTAssertEqual(calls.increment(), 2, "perform ran once even though it threw")
    }

    func testAThrowingWaveDoesNotPoisonTheNextRefresh() async throws {
        let coordinator = RefreshCoordinator()

        await assertThrowsAsync {
            try await coordinator.refreshedAccessToken { throw RefreshError.transient }
        } onError: { error in
            XCTAssertEqual(error as? RefreshError, .transient)
        }

        let recovered = try await coordinator.refreshedAccessToken { "A2" }
        XCTAssertEqual(recovered, "A2", "defer cleared the slot even on throw")
    }

    func testASecondWaveArrivingMidFlightJoinsTheSameTask() async throws {
        let coordinator = RefreshCoordinator()
        let calls = LockedCounter()
        let perform: @Sendable () async throws -> String = {
            calls.increment()
            try? await Task.sleep(for: .milliseconds(80))
            return "A2"
        }

        let tokens = try await withThrowingTaskGroup(of: String.self) { group -> [String] in
            for _ in 0 ..< 5 {
                group.addTask { try await coordinator.refreshedAccessToken(perform: perform) }
            }
            try? await Task.sleep(for: .microseconds(200))
            for _ in 0 ..< 5 {
                group.addTask { try await coordinator.refreshedAccessToken(perform: perform) }
            }
            var collected: [String] = []
            for try await value in group {
                collected.append(value)
            }
            return collected
        }

        XCTAssertEqual(tokens, Array(repeating: "A2", count: 10))
        XCTAssertEqual(calls.increment(), 2, "both waves joined the one in-flight task")
    }
}
