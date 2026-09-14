import Foundation

/// Repository protocol for plugin domain operations.
public protocol PluginRepository: Sendable {
    func getData() async throws -> PluginData
    func syncData() async throws
}
