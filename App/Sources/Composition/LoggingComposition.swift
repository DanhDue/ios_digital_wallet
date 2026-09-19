import Core
import D3NexusLogging
import Foundation
import os

/// Composition root factory establishing the centralized logging subsystem.
public enum LoggingComposition {
    private static let lock = OSAllocatedUnfairLock<Bool>(initialState: false)

    /// Builds and initializes the logging engine, returning a backward-compatible `Core.Logger`.
    ///
    /// Ensures `LoggingSystem.bootstrap` is called at most once per process lifetime, even across
    /// multiple composition re-evaluations in test runs.
    public static func buildCoreLogger(
        subsystem: String = "com.danhdue.iOSDigitalWallet"
    ) -> Core.Logger {
        let toggleStore = ToggleStore()
        let manager = LogManagerImpl(toggleStore: toggleStore)
        let osLogAppender = OSLogAppender(subsystem: subsystem)
        manager.registerAppender(osLogAppender)

        #if DEBUG
            manager.registerAppender(PulseAppender(store: .shared))
        #endif

        D3NexusLogger.initialize(manager: manager)

        let shouldBootstrap = lock.withLock { hasBootstrapped in
            if !hasBootstrapped {
                hasBootstrapped = true
                return true
            }
            return false
        }

        if shouldBootstrap {
            LoggingSystemBootstrap.bootstrap(manager: manager)
        }

        let rootLogger = manager.getLogger(module: "App")
        return D3NexusCoreLoggerAdapter(logger: rootLogger)
    }
}
