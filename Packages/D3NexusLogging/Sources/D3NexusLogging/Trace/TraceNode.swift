import Foundation

/// Value-type node representing a log record and its causal child nodes in a trace tree.
public struct TraceNode: Sendable, Equatable {
    public let record: LogRecord
    public var children: [TraceNode]

    public init(record: LogRecord, children: [TraceNode] = []) {
        self.record = record
        self.children = children
    }
}
