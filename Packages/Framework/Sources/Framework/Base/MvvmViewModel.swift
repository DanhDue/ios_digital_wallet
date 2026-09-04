import Combine
import Foundation

/// Base class for every ViewModel in the template. Owns a `cancellables` bag and
/// a single teardown hook (`onClear()`), mirroring the Kotlin `MvvmViewModel`
/// (Source Spec §5.2).
///
/// `@MainActor` because every subclass drives SwiftUI state. Real teardown
/// belongs in `onClear()`, which the owner calls from the main actor.
@MainActor
open class MvvmViewModel: ObservableObject {
    /// Combine subscriptions owned by this ViewModel. Emptied by `onClear()`.
    public var cancellables = Set<AnyCancellable>()

    public init() {}

    /// Release resources held by this ViewModel. Subclasses override to add
    /// their own cleanup and must call `super.onClear()`.
    open func onClear() {
        cancellables.removeAll()
    }
}
