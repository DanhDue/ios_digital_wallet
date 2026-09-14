import FactoryKit
import Foundation

/// Implementation of Pigeon Host API delegating calls to Clean Architecture UseCases.
public final class MyPluginHostApiImpl: MyPluginHostApi, @unchecked Sendable {
    private let getDataUseCase: GetDataUseCase

    public init(getDataUseCase: GetDataUseCase = PluginContainer.shared.getDataUseCase()) {
        self.getDataUseCase = getDataUseCase
    }

    public func getData(completion: @escaping @Sendable (Result<PluginDataMessage, Error>) -> Void) {
        Task {
            do {
                let data = try await getDataUseCase.execute()
                let message = PluginDataMessage(id: data.id, title: data.title)
                completion(.success(message))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
