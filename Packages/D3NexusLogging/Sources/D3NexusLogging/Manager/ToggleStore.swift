import Foundation
import os

/// Thread-safe persistence store for module mute toggles and appender kill-switches.
public final class ToggleStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let lock = OSAllocatedUnfairLock()

    private static let moduleKey = "logging.module_toggles"
    private static let appenderKey = "logging.appender_toggles"

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func setModuleEnabled(_ module: String, enabled: Bool) {
        lock.withLock {
            var toggles = loadDictionary(forKey: Self.moduleKey)
            toggles[module] = enabled
            userDefaults.set(toggles, forKey: Self.moduleKey)
        }
    }

    public func isModuleEnabled(_ module: String) -> Bool {
        lock.withLock {
            let toggles = loadDictionary(forKey: Self.moduleKey)
            return toggles[module] ?? true
        }
    }

    public func setAppenderEnabled(_ appenderId: String, enabled: Bool) {
        lock.withLock {
            var toggles = loadDictionary(forKey: Self.appenderKey)
            toggles[appenderId] = enabled
            userDefaults.set(toggles, forKey: Self.appenderKey)
        }
    }

    public func isAppenderEnabled(_ appenderId: String) -> Bool {
        lock.withLock {
            let toggles = loadDictionary(forKey: Self.appenderKey)
            return toggles[appenderId] ?? true
        }
    }

    private func loadDictionary(forKey key: String) -> [String: Bool] {
        guard let raw = userDefaults.dictionary(forKey: key) else {
            return [:]
        }
        var result = [String: Bool]()
        for (module, value) in raw {
            if let boolValue = value as? Bool {
                result[module] = boolValue
            }
        }
        return result
    }
}
