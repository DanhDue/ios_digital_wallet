import Foundation
import Logging

/// Provides a mechanism to bootstrap swift-log's global LoggingSystem with D3NexusLogHandler.
public enum LoggingSystemBootstrap {
    /// Bootstraps swift-log with a global `LogManager`.
    ///
    /// Must only be called once during process startup (typically at the composition root in `App/`).
    public static func bootstrap(manager: any LogManager) {
        LoggingSystem.bootstrap { label in
            D3NexusLogHandler(label: label, manager: manager)
        }
    }
}
