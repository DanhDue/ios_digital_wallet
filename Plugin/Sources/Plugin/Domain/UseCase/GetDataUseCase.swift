import Foundation

/// Use case to fetch plugin data from the repository.
public struct GetDataUseCase: Sendable {
    private let repository: PluginRepository

    public init(repository: PluginRepository) {
        self.repository = repository
    }

    public func execute() async throws -> PluginData {
        try await repository.getData()
    }
}
