import Platform
import SwiftUI

/// Owns the mapping from SwiftUI's `ScenePhase` to `AppLifecycleChanged`
/// (Source Spec §8). The `@main` app attaches it via
/// `.onChange(of: scenePhase)`; it is the natural home for `ScenePhase` because
/// only the `App` layer sees it.
///
///   `.active`     → `AppLifecycleChanged(state: .foreground)`
///   `.inactive`   → `AppLifecycleChanged(state: .inactive)`
///   `.background` → `AppLifecycleChanged(state: .background)`
@MainActor
final class LifecycleObserver {
    private let eventBus: AppEventBus

    init(eventBus: AppEventBus) {
        self.eventBus = eventBus
    }

    /// Map + publish a raw `ScenePhase`. Tests call this directly with each
    /// phase value.
    func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            publish(.foreground)
        case .inactive:
            publish(.inactive)
        case .background:
            publish(.background)
        @unknown default:
            break
        }
    }

    /// Publish an already-mapped lifecycle state (host-agnostic entry point).
    func handle(_ state: AppLifecycleChanged.State) {
        publish(state)
    }

    private func publish(_ state: AppLifecycleChanged.State) {
        eventBus.publish(AppLifecycleChanged(state: state))
    }
}
