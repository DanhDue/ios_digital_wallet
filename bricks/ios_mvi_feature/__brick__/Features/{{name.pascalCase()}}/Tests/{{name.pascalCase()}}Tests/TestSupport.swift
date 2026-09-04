import Combine
import Core
import Foundation
import Framework
import XCTest
@testable import {{name.pascalCase()}}

// See: Features/Settings/Tests/SettingsTests/TestSupport.swift

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

// MARK: - Spy repository

/// Counts calls, records saved entities, lets a test script the results of
/// `load` / `save`.
@MainActor
final class Spy{{name.pascalCase()}}Repository: {{name.pascalCase()}}Repository {
    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var savedEntities: [{{name.pascalCase()}}Entity] = []

    var loadResult: DataState<{{name.pascalCase()}}Entity> = .success(.default)
    var saveResult: DataState<Void> = .success(())

    func load() async -> DataState<{{name.pascalCase()}}Entity> {
        loadCallCount += 1
        return loadResult
    }

    func save(_ entity: {{name.pascalCase()}}Entity) async -> DataState<Void> {
        saveCallCount += 1
        savedEntities.append(entity)
        return saveResult
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
