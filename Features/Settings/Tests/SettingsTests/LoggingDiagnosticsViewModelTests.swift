#if DEBUG
    import Combine
    import XCTest
    @testable import D3NexusLogging
    @testable import Settings

    @MainActor
    final class LoggingDiagnosticsViewModelTests: XCTestCase {
        private func makeSuite() -> UserDefaults {
            let name = "test.diagnostics.\(UUID().uuidString)"
            guard let suite = UserDefaults(suiteName: name) else {
                fatalError("Could not create test UserDefaults suite")
            }
            return suite
        }

        private func trackForMemoryLeaks(
            _ instance: AnyObject,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            addTeardownBlock { [weak instance] in
                XCTAssertNil(
                    instance,
                    "Instance should have been deallocated. Potential memory leak.",
                    file: file,
                    line: line
                )
            }
        }

        func testInitialStateReadsFromLogManager() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            XCTAssertFalse(sut.isConsolePresented)
            for module in LoggingDiagnosticsViewModel.availableModules {
                XCTAssertEqual(sut.moduleToggles[module], true, "Module \(module) should default to enabled")
            }
            for appender in LoggingDiagnosticsViewModel.availableAppenders {
                XCTAssertEqual(sut.appenderToggles[appender], true, "Appender \(appender) should default to enabled")
            }
        }

        func testSetModuleEnabledUpdatesStateAndManager() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            sut.setModuleEnabled("Settings", enabled: false)
            XCTAssertEqual(sut.moduleToggles["Settings"], false)
            XCTAssertFalse(manager.isModuleEnabled("Settings"))

            sut.setModuleEnabled("Settings", enabled: true)
            XCTAssertEqual(sut.moduleToggles["Settings"], true)
            XCTAssertTrue(manager.isModuleEnabled("Settings"))
        }

        func testSetAppenderEnabledUpdatesStateAndManager() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            sut.setAppenderEnabled("pulse", enabled: false)
            XCTAssertEqual(sut.appenderToggles["pulse"], false)
            XCTAssertFalse(manager.isAppenderEnabled("pulse"))

            sut.setAppenderEnabled("pulse", enabled: true)
            XCTAssertEqual(sut.appenderToggles["pulse"], true)
            XCTAssertTrue(manager.isAppenderEnabled("pulse"))
        }

        func testTogglesPersistAcrossSimulatedRestart() {
            let suite = makeSuite()
            let manager1 = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let center1 = NotificationCenter()
            let sut1 = LoggingDiagnosticsViewModel(logManager: manager1, notificationCenter: center1)

            sut1.setModuleEnabled("Scanner", enabled: false)
            sut1.setAppenderEnabled("oslog", enabled: false)

            // Simulate new app session with fresh manager & ViewModel reading from same store
            let manager2 = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let center2 = NotificationCenter()
            let sut2 = LoggingDiagnosticsViewModel(logManager: manager2, notificationCenter: center2)
            trackForMemoryLeaks(sut2)

            XCTAssertEqual(sut2.moduleToggles["Scanner"], false)
            XCTAssertEqual(sut2.appenderToggles["oslog"], false)
            XCTAssertEqual(sut2.moduleToggles["App"], true)
        }

        func testShakeNotificationFlipsConsolePresented() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            XCTAssertFalse(sut.isConsolePresented)

            notificationCenter.post(name: Notification.Name("UIDeviceDidShakeNotification"), object: nil)
            XCTAssertTrue(sut.isConsolePresented)
        }

        func testRepeatedShakesWhileOpenAreIdempotent() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            sut.handleShake()
            XCTAssertTrue(sut.isConsolePresented)

            // Repeat 3 more shakes
            sut.handleShake()
            sut.handleShake()
            sut.handleShake()
            XCTAssertTrue(sut.isConsolePresented)
        }

        func testOpenAndDismissConsole() {
            let suite = makeSuite()
            let manager = LogManagerImpl(toggleStore: ToggleStore(userDefaults: suite))
            let notificationCenter = NotificationCenter()
            let sut = LoggingDiagnosticsViewModel(logManager: manager, notificationCenter: notificationCenter)
            trackForMemoryLeaks(sut)

            sut.openConsole()
            XCTAssertTrue(sut.isConsolePresented)

            // Calling openConsole again while already open is a no-op
            sut.openConsole()
            XCTAssertTrue(sut.isConsolePresented)

            sut.dismissConsole()
            XCTAssertFalse(sut.isConsolePresented)
        }

        func testObserverTeardownOnDeinit() {
            let notificationCenter = NotificationCenter()
            var sut: LoggingDiagnosticsViewModel? = LoggingDiagnosticsViewModel(
                logManager: LogManagerImpl(toggleStore: ToggleStore(userDefaults: makeSuite())),
                notificationCenter: notificationCenter
            )
            weak var weakRef = sut
            XCTAssertNotNil(weakRef)

            sut = nil
            XCTAssertNil(weakRef, "LoggingDiagnosticsViewModel should deallocate and remove its observer")

            // Notification after dealloc should not crash or trigger zombies
            notificationCenter.post(name: Notification.Name("UIDeviceDidShakeNotification"), object: nil)
        }
    }
#endif
