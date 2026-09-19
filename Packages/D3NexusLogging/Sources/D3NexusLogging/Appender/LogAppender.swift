import Foundation

/// Protocol representing a logging destination or telemetry sink.
public protocol LogAppender: Sendable {
    /// Unique identifier for this appender (e.g., "pulse", "oslog").
    var id: String { get }

    /// Indicates whether this appender respects per-module mute toggles.
    ///
    /// Local debug appenders set this to `true`, while production telemetry sets it to `false`.
    var respectsModuleToggle: Bool { get }

    /// Appends a sanitized log record.
    func append(_ record: LogRecord)
}
