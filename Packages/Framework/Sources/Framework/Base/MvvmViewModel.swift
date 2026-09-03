import Combine
import Foundation

/// Base class for every ViewModel in the template. Owns a `cancellables` bag and
/// a single teardown hook (`onClear()`), mirroring the Kotlin `MvvmViewModel`
/// (Source Spec §5.2).
///
/// `@MainActor` because every subclass drives SwiftUI state. Under the Swift 6
/// language mode a plain `deinit` is *nonisolated* and may NOT touch the
/// non-`Sendable` `cancellables` bag, so the `deinit` below is declared
/// `isolated` (SE-0371). Real teardown still belongs in `onClear()`, which the
/// owner calls from the main actor; the `deinit` is only a backstop.
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

    /// `isolated deinit` (SE-0371, available in this 6.3.3 toolchain) so the
    /// deinitializer runs on the main actor and may touch the non-`Sendable`
    /// `cancellables` bag. A plain nonisolated `deinit` cannot under the Swift 6
    /// language mode. Correct teardown is still `onClear()`; this is a backstop.
    isolated deinit {
        cancellables.removeAll()
    }
}
