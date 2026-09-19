import Foundation
import os

/// Global logging facade providing convenient access to module loggers and runtime toggles.
public enum D3NexusLogger {
    private struct State {
        var manager: (any LogManager)?
        var assertsOnUninitialized: Bool = true
    }

    private static let storage = OSAllocatedUnfairLock<State>(initialState: State())

    /// Initializes the global logger with a concrete `LogManager`.
    public static func initialize(manager: any LogManager) {
        storage.withLock {
            $0.manager = manager
        }
    }

    /// Obtains a root logger for the specified module.
    ///
    /// If uninitialized, returns a `NoOpLogger` and triggers assertionFailure in DEBUG (unless disabled for testing).
    public static func getLogger(_ module: String) -> any LoggerProtocol {
        let (currentManager, shouldAssert) = storage.withLock { ($0.manager, $0.assertsOnUninitialized) }
        guard let currentManager else {
            #if DEBUG
                if shouldAssert {
                    assertionFailure("D3NexusLogger must be initialized before calling getLogger(_:)")
                }
            #endif
            return NoOpLogger(module: module)
        }
        return currentManager.getLogger(module: module)
    }

    /// Sets the mute status for a specific module.
    public static func setModuleEnabled(_ module: String, enabled: Bool) {
        let currentManager = storage.withLock { $0.manager }
        currentManager?.setModuleEnabled(module, enabled: enabled)
    }

    /// Queries whether a module is currently unmuted.
    public static func isModuleEnabled(_ module: String) -> Bool {
        let currentManager = storage.withLock { $0.manager }
        return currentManager?.isModuleEnabled(module) ?? true
    }

    /// Sets the kill-switch status for an appender.
    public static func setAppenderEnabled(_ appenderId: String, enabled: Bool) {
        let currentManager = storage.withLock { $0.manager }
        currentManager?.setAppenderEnabled(appenderId, enabled: enabled)
    }

    /// Queries whether an appender is currently enabled.
    public static func isAppenderEnabled(_ appenderId: String) -> Bool {
        let currentManager = storage.withLock { $0.manager }
        return currentManager?.isAppenderEnabled(appenderId) ?? true
    }

    /// Resets the facade state for unit test isolation.
    public static func resetForTesting(assertsOnUninitialized: Bool = false) {
        storage.withLock {
            $0.manager = nil
            $0.assertsOnUninitialized = assertsOnUninitialized
        }
    }
}
