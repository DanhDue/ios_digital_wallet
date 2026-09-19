import Foundation
import os

/// Thread-safe central logging engine managing appenders and dispatching log records.
public final class LogManagerImpl: LogManager, @unchecked Sendable {
    private let toggleStore: ToggleStore
    private let lock = OSAllocatedUnfairLock()
    private var appenders: [any LogAppender] = []

    public init(toggleStore: ToggleStore = ToggleStore()) {
        self.toggleStore = toggleStore
    }

    public func getLogger(module: String) -> any LoggerProtocol {
        LoggerImpl(
            module: module,
            traceId: TraceIdentifier.newTraceId(),
            spanId: TraceIdentifier.newSpanId(),
            parentSpanId: nil,
            manager: self
        )
    }

    public func registerAppender(_ appender: any LogAppender) {
        lock.withLock {
            appenders.append(appender)
        }
    }

    public func log(_ record: LogRecord) {
        let activeAppenders = lock.withLock { appenders }
        let isModuleMuted = !isModuleEnabled(record.module)

        for appender in activeAppenders {
            guard isAppenderEnabled(appender.id) else { continue }
            if appender.respectsModuleToggle, isModuleMuted {
                continue
            }

            appender.append(record)
        }
    }

    public func setModuleEnabled(_ module: String, enabled: Bool) {
        toggleStore.setModuleEnabled(module, enabled: enabled)
    }

    public func isModuleEnabled(_ module: String) -> Bool {
        toggleStore.isModuleEnabled(module)
    }

    public func setAppenderEnabled(_ appenderId: String, enabled: Bool) {
        toggleStore.setAppenderEnabled(appenderId, enabled: enabled)
    }

    public func isAppenderEnabled(_ appenderId: String) -> Bool {
        toggleStore.isAppenderEnabled(appenderId)
    }
}
