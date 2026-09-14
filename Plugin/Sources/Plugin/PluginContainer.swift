import FactoryKit
import Foundation

/// Dedicated Dependency Injection container for the Plugin package.
/// Subclasses `SharedContainer` so multiple plugins can co-exist without colliding on global registrations.
public final class PluginContainer: SharedContainer, @unchecked Sendable {
    public static let shared = PluginContainer()
    public let manager = ContainerManager()

    public init() {}

    public var repository: Factory<PluginRepository> {
        self { PluginRepositoryImpl() }
    }

    public var getDataUseCase: Factory<GetDataUseCase> {
        self { GetDataUseCase(repository: self.repository()) }
    }

    public var syncDataUseCase: Factory<SyncDataUseCase> {
        self { SyncDataUseCase(repository: self.repository()) }
    }

    @MainActor
    public var myPluginViewModel: Factory<MyPluginViewModel> {
        self { MyPluginViewModel(getDataUseCase: self.getDataUseCase()) }
    }
}
