import Foundation

/// Represents an immutable log event carrying structured metadata and W3C trace identifiers.
public struct LogRecord: Sendable, Equatable, Codable {
    public let module: String
    public let level: LogLevel
    public let message: String
    public let timestamp: Date
    public let traceId: String
    public let spanId: String
    public let parentSpanId: String?
    public let errorDescription: String?
    public let metadata: [String: String]

    public init(
        module: String,
        level: LogLevel,
        message: String,
        timestamp: Date = Date(),
        traceId: String,
        spanId: String,
        parentSpanId: String? = nil,
        errorDescription: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.module = module
        self.level = level
        self.message = message
        self.timestamp = timestamp
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
        self.errorDescription = errorDescription
        self.metadata = metadata
    }
}
