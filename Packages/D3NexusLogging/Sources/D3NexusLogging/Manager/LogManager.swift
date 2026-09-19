import Foundation

/// Central logging orchestrator managing appenders, module toggles, and logger instances.
public protocol LogManager: Sendable {
    /// Obtains a root logger for the specified module.
    func getLogger(module: String) -> any LoggerProtocol

    /// Registers a new telemetry appender.
    func registerAppender(_ appender: any LogAppender)

    /// Dispatches a log record through the appender pipeline.
    func log(_ record: LogRecord)

    /// Sets the mute status for a specific module.
    func setModuleEnabled(_ module: String, enabled: Bool)

    /// Queries whether a module is currently unmuted.
    func isModuleEnabled(_ module: String) -> Bool

    /// Sets the kill-switch status for a specific telemetry appender.
    func setAppenderEnabled(_ appenderId: String, enabled: Bool)

    /// Queries whether an appender is currently enabled.
    func isAppenderEnabled(_ appenderId: String) -> Bool
}
