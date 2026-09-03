import Combine
import Foundation
import Platform
import SwiftUI
import XCTest
@testable import Shell

// MARK: - Combine recorder

/// Sinks a `Never`-failing publisher into an ordered array so tests can assert
/// the exact emission *sequence*, not just the terminal value. Lock-guarded and
/// `@unchecked Sendable` so the sink closure needs no actor hop under Swift 6
/// strict concurrency. Subscribe BEFORE the action under test.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: some Publisher<Value, Never>) {
        cancellable = publisher.sink { [weak self] value in
            guard let self else { return }
            lock.lock()
            storage.append(value)
            lock.unlock()
        }
    }

    var values: [Value] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        values.count
    }

    /// Detaches the sink. Emissions after this are not recorded.
    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}

// MARK: - Visibility-event projection

/// `Equatable` projection of `ShellTabVisibilityChanged` for exact-sequence
/// assertions — the shipping event type is deliberately not `Equatable`.
struct VisibilityChange: Equatable {
    let tabIndex: Int
    let isVisible: Bool

    init(event: ShellTabVisibilityChanged) {
        tabIndex = event.tabIndex
        isVisible = event.isVisible
    }

    init(tab: Int, visible: Bool) {
        tabIndex = tab
        isVisible = visible
    }
}

extension AppEventBus {
    /// A recorder over the `[VisibilityChange]` sequence this bus publishes.
    /// Subscribed at call time — create it before the dispatch under test.
    func visibilityRecorder() -> Recorder<VisibilityChange> {
        Recorder(on(ShellTabVisibilityChanged.self).map { VisibilityChange(event: $0) })
    }
}

// MARK: - System-under-test bundle

/// The three collaborators every ViewModel test needs, kept in a named struct so
/// helpers can return them without tripping SwiftLint's `large_tuple` rule.
@MainActor
struct ShellTestEnv {
    let sut: ShellViewModel
    let router: AppRouter
    let bus: AppEventBus

    init(tabCount: Int = 3, initialTab: Int = 2, routerInitialTab: Int? = nil) {
        router = AppRouter(tabCount: tabCount, initialTab: routerInitialTab ?? initialTab)
        bus = AppEventBus()
        sut = ShellViewModel(
            config: ShellConfig(tabCount: tabCount, initialTab: initialTab),
            router: router,
            eventBus: bus
        )
    }
}

// MARK: - Fake route provider

/// A stand-in feature provider. Proves the shell resolves tab content through
/// `AppRouter` without naming any concrete feature module.
final class FakeRouteProvider: RouteProvider {
    private(set) var destinationCallCount = 0
    private let label: String

    init(label: String) {
        self.label = label
    }

    func canHandle(_ route: any AppRoute) -> Bool {
        route is AppRoutes.SettingsRoot || route is AppRoutes.ScannerRoot
    }

    func destination(for _: any AppRoute) -> AnyView {
        destinationCallCount += 1
        return AnyView(Text(label))
    }
}

// MARK: - Source enumeration (feature-blindness grep)

/// Every `.swift` file under `Packages/Shell/Sources`.
func shellSourceFiles(file: StaticString = #filePath) throws -> [URL] {
    let sources = URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent() // ShellTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Shell
        .appendingPathComponent("Sources")

    guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
        return []
    }
    return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
}
