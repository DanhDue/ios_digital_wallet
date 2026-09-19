import Foundation
import os

/// Unified Logging (`os.Logger`) appender for system-level diagnostics and Console.app capture.
///
/// Privacy & Security Rationale:
/// This appender logs with `privacy: .public` intentionally because all `LogRecord` instances
/// are pre-sanitized by `Redactor` at the `LogManagerImpl` dispatch boundary. Never bypass
/// or alter this ordering without updating the security model.
///
/// System Diagnostics:
/// Sets `respectsModuleToggle = false` to guarantee system-level diagnostics remain active
/// even when a developer mutes modules in the in-app debug UI.
public final class OSLogAppender: LogAppender, @unchecked Sendable {
    public typealias EmissionSink = @Sendable (
        _ subsystem: String,
        _ category: String,
        _ level: LogLevel,
        _ message: String
    ) -> Void

    public let id: String
    public let respectsModuleToggle: Bool = false

    private let subsystem: String
    private let sink: EmissionSink?

    /// Initializes an OSLogAppender with a required subsystem.
    ///
    /// - Parameters:
    ///   - subsystem: Reverse-DNS subsystem identifier (e.g. `com.example.app`). Must be explicitly provided.
    ///   - id: Unique appender identifier for toggles, defaulting to `"oslog"`.
    ///   - sink: Optional custom sink hook for unit test validation. Defaults to nil (direct Unified Logging).
    public init(
        subsystem: String,
        id: String = "oslog",
        sink: EmissionSink? = nil
    ) {
        self.subsystem = subsystem
        self.id = id
        self.sink = sink
    }

    public func append(_ record: LogRecord) {
        let prefix = "[\(record.traceId)][\(record.spanId)] "
        var formattedMessage = "\(prefix)\(record.message)"
        if let errorDescription = record.errorDescription {
            formattedMessage += " | error: \(errorDescription)"
        }

        if let sink {
            sink(subsystem, record.module, record.level, formattedMessage)
            return
        }

        let logger = os.Logger(subsystem: subsystem, category: record.module)
        switch record.level {
        case .verbose, .debug:
            logger.debug("\(formattedMessage, privacy: .public)")
        case .info:
            logger.info("\(formattedMessage, privacy: .public)")
        case .warning:
            logger.warning("\(formattedMessage, privacy: .public)")
        case .error:
            logger.error("\(formattedMessage, privacy: .public)")
        }
    }
}
