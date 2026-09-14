import Foundation

/// Default implementation of PluginRepository as an actor.
actor PluginRepositoryImpl: PluginRepository {
    private var currentData: PluginData

    init(initialData: PluginData? = nil) {
        currentData = initialData ?? PluginData(id: "default-id", title: "Devbed Plugin Data")
    }

    func getData() async throws -> PluginData {
        currentData
    }

    func syncData() async throws {
        currentData = PluginData(id: UUID().uuidString, title: "Synced Devbed Plugin Data", timestamp: Date())
    }
}
