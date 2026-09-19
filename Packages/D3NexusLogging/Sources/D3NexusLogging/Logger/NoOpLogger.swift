import Foundation

/// A null-object logger that silently discards all events.
public struct NoOpLogger: LoggerProtocol, Sendable {
    public let module: String
    public let traceId: String
    public let spanId: String
    public let parentSpanId: String?

    public init(
        module: String = "NoOp",
        traceId: String = "00000000000000000000000000000000",
        spanId: String = "0000000000000000",
        parentSpanId: String? = nil
    ) {
        self.module = module
        self.traceId = traceId
        self.spanId = spanId
        self.parentSpanId = parentSpanId
    }

    public func verbose(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
    public func debug(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
    public func info(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
    public func warning(_: String, error _: (any Error)?, metadata _: [String: String]?) {}
    public func error(_: String, error _: (any Error)?, metadata _: [String: String]?) {}

    public func withSpan() -> any LoggerProtocol {
        self
    }
}
