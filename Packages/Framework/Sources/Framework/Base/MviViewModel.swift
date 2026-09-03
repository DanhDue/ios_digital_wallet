import Combine
import Foundation

/// Generic MVI base (Source Spec §5.4). A single `uiState`, a `viewState` render
/// envelope, two event channels, and one entry point — `dispatch` — that routes
/// to the overridable `onAction`. Subclasses override `onAction` only.
///
/// Deviation from the spec's literal signature: the async-effect helper
/// (`AsyncEffect.swift`) takes a `@MainActor`-isolated operation closure rather
/// than a bare `() async -> Void`. Effects mutate main-actor ViewModel state
/// (`reduce`, `handleError`, …); isolating the closure is both more correct and
/// the only spelling that type-checks under the Swift 6 language mode without
/// forcing every call site through `MainActor.run`.
@MainActor
open class MviViewModel<STATE, ACTION, EVENT>: MvvmViewModel {
    @Published public private(set) var uiState: STATE
    @Published public private(set) var viewState: ViewState<STATE> = .loading

    /// One-consumer convention (mirrors a Kotlin `Channel`).
    public let eventSubject = PassthroughSubject<EVENT, Never>()
    /// Multi-consumer (mirrors a Kotlin `SharedFlow`).
    public let sharedEventSubject = PassthroughSubject<EVENT, Never>()

    /// One running `Task` per effect key (Source Spec §5.5).
    public internal(set) var effectTasks: [AnyHashable: Task<Void, Never>] = [:]

    /// Generation token per effect key. A completing effect only clears its slot
    /// when its token still matches — i.e. a newer `launch(sameKey:)` has not
    /// already replaced it. Without this guard a superseded effect's completion
    /// tail would wipe the *new* effect's entry (a latent bug in the spec's
    /// sample code), breaking same-key cancellation and teardown guarantees.
    var effectTokens: [AnyHashable: UUID] = [:]

    public init(initialState: STATE) {
        uiState = initialState
        super.init()
    }

    /// The single, non-overridable entry point. Mirrors Kotlin's `final`
    /// `dispatch`: the contract cannot be bypassed by a subclass.
    public final func dispatch(_ action: ACTION) {
        onAction(action)
    }

    /// Override point. Reduce synchronously and/or start effects via `launch`.
    open func onAction(_: ACTION) {}

    /// Mutates `uiState` in place (value-type idiom mirroring Kotlin `copy()`).
    public func reduce(_ transform: (inout STATE) -> Void) {
        transform(&uiState)
    }

    public func startLoading() {
        viewState = .loading
    }

    public func handleError(_ error: Error) {
        viewState = .error(error)
    }

    public func showContent() {
        viewState = .content(uiState)
    }

    public func emit(_ event: EVENT) {
        eventSubject.send(event)
    }

    public func emitShared(_ event: EVENT) {
        sharedEventSubject.send(event)
    }

    /// Cancels every in-flight effect, then runs the base teardown. Subclasses
    /// that override must call `super.onClear()`.
    override open func onClear() {
        cancelEffects()
        super.onClear()
    }
}
