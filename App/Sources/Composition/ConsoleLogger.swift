import Core
import Foundation
import os

/// The composition root's `Core.Logger`: forwards every line to the unified
/// logging system (`os.Logger`). `Core` never picks a backend — the `App` does,
/// here, once.
///
/// `@unchecked Sendable`: the sole stored value is an `os.Logger`, which is
/// itself `Sendable` and is never reassigned.
final class ConsoleLogger: Core.Logger, @unchecked Sendable {
    private let backend: os.Logger

    init(subsystem: String = "com.danhdue.iOSDigitalWallet", category: String = "App") {
        backend = os.Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: String, file _: String, function _: String, line _: Int) {
        backend.debug("\(message, privacy: .public)")
    }

    func info(_ message: String, file _: String, function _: String, line _: Int) {
        backend.info("\(message, privacy: .public)")
    }

    func error(_ message: String, file _: String, function _: String, line _: Int) {
        backend.error("\(message, privacy: .public)")
    }
}
