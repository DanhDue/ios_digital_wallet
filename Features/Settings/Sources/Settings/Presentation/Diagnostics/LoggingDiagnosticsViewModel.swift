#if DEBUG
    import Combine
    import D3NexusLogging
    import Foundation

    /// Drives the developer diagnostics screen, controlling module mutes, appender kill-switches,
    /// and console presentation state.
    public final class LoggingDiagnosticsViewModel: ObservableObject, @unchecked Sendable {
        public static let availableModules = ["App", "Network", "Settings", "Scanner", "Core"]
        public static let availableAppenders = ["oslog", "pulse"]

        @Published public private(set) var moduleToggles: [String: Bool] = [:]
        @Published public private(set) var appenderToggles: [String: Bool] = [:]
        @Published public var isConsolePresented: Bool = false

        private let logManager: any LogManager
        private var shakeObserver: (any NSObjectProtocol)?
        private let notificationCenter: NotificationCenter

        public init(
            logManager: any LogManager = LogManagerImpl(),
            notificationCenter: NotificationCenter = .default
        ) {
            self.logManager = logManager
            self.notificationCenter = notificationCenter
            refreshToggles()

            // Register shake notification observer (UC-5.1 / UC-5.2)
            shakeObserver = notificationCenter.addObserver(
                forName: Notification.Name("UIDeviceDidShakeNotification"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleShake()
            }
        }

        deinit {
            if let observer = shakeObserver {
                notificationCenter.removeObserver(observer)
            }
        }

        public func refreshToggles() {
            var modules: [String: Bool] = [:]
            for module in Self.availableModules {
                modules[module] = logManager.isModuleEnabled(module)
            }
            moduleToggles = modules

            var appenders: [String: Bool] = [:]
            for appender in Self.availableAppenders {
                appenders[appender] = logManager.isAppenderEnabled(appender)
            }
            appenderToggles = appenders
        }

        public func setModuleEnabled(_ module: String, enabled: Bool) {
            logManager.setModuleEnabled(module, enabled: enabled)
            moduleToggles[module] = enabled
        }

        public func setAppenderEnabled(_ appenderId: String, enabled: Bool) {
            logManager.setAppenderEnabled(appenderId, enabled: enabled)
            appenderToggles[appenderId] = enabled
        }

        /// Handles shake gesture idempotently (UC-5.2: multiple shakes while open do not stack).
        public func handleShake() {
            guard !isConsolePresented else { return }
            isConsolePresented = true
        }

        public func openConsole() {
            guard !isConsolePresented else { return }
            isConsolePresented = true
        }

        public func dismissConsole() {
            isConsolePresented = false
        }
    }
#endif
