import Foundation

/// Domain model representing data handled by the plugin.
public struct PluginData: Equatable, Sendable {
    public let id: String
    public let title: String
    public let timestamp: Date

    public init(id: String, title: String, timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
    }
}
