import Core
import D3NexusLogging
import Foundation

/// Backward-compatibility adapter bridging `Core.Logger` call sites to `D3NexusLogging.LoggerProtocol`.
///
/// Preserves call-site provenance (`file`, `function`, `line`) as metadata attributes without mutating
/// existing call sites in Core, Network, Framework, or Feature repositories.
public final class D3NexusCoreLoggerAdapter: Core.Logger, @unchecked Sendable {
    private let logger: any LoggerProtocol

    public init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    public func debug(_ message: String, file: String, function: String, line: Int) {
        logger.debug(message, metadata: [
            "file": file,
            "function": function,
            "line": "\(line)",
        ])
    }

    public func info(_ message: String, file: String, function: String, line: Int) {
        logger.info(message, metadata: [
            "file": file,
            "function": function,
            "line": "\(line)",
        ])
    }

    public func error(_ message: String, file: String, function: String, line: Int) {
        logger.error(message, error: nil, metadata: [
            "file": file,
            "function": function,
            "line": "\(line)",
        ])
    }
}
