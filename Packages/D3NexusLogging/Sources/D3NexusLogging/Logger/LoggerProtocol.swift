import Foundation

/// Defines the public logging contract for emitting structured log entries and creating child spans.
public protocol LoggerProtocol: Sendable {
    /// Module name associated with this logger.
    var module: String { get }

    /// W3C distributed trace identifier (32 hex characters).
    var traceId: String { get }

    /// W3C span identifier (16 hex characters).
    var spanId: String { get }

    /// Optional parent span identifier if this logger is a child span.
    var parentSpanId: String? { get }

    /// Emits a verbose-level log message.
    func verbose(_ message: String, error: (any Error)?, metadata: [String: String]?)

    /// Emits a debug-level log message.
    func debug(_ message: String, error: (any Error)?, metadata: [String: String]?)

    /// Emits an info-level log message.
    func info(_ message: String, error: (any Error)?, metadata: [String: String]?)

    /// Emits a warning-level log message.
    func warning(_ message: String, error: (any Error)?, metadata: [String: String]?)

    /// Emits an error-level log message.
    func error(_ message: String, error: (any Error)?, metadata: [String: String]?)

    /// Creates a child logger preserving the same `traceId`, a new `spanId`,
    /// and linking `parentSpanId` as a value type without retaining circular references.
    func withSpan() -> any LoggerProtocol
}

public extension LoggerProtocol {
    func verbose(_ message: String, error: (any Error)? = nil, metadata: [String: String]? = nil) {
        verbose(message, error: error, metadata: metadata)
    }

    func debug(_ message: String, error: (any Error)? = nil, metadata: [String: String]? = nil) {
        debug(message, error: error, metadata: metadata)
    }

    func info(_ message: String, error: (any Error)? = nil, metadata: [String: String]? = nil) {
        info(message, error: error, metadata: metadata)
    }

    func warning(_ message: String, error: (any Error)? = nil, metadata: [String: String]? = nil) {
        warning(message, error: error, metadata: metadata)
    }

    func error(_ message: String, error: (any Error)? = nil, metadata: [String: String]? = nil) {
        self.error(message, error: error, metadata: metadata)
    }
}
