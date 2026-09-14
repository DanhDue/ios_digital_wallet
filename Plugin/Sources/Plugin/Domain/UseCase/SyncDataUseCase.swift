import Foundation

/// Use case to trigger data synchronization via the repository.
public struct SyncDataUseCase: Sendable {
    private let repository: PluginRepository

    public init(repository: PluginRepository) {
        self.repository = repository
    }

    public func execute() async throws {
        try await repository.syncData()
    }
}
