import Foundation

/// §5.5 async-effect pattern. `onAction` may kick off async work (a UseCase
/// call); each *effect key* keeps at most one `Task`. A new action with the same
/// key cancels the in-flight `Task` before starting a new one — the Swift
/// analogue of `viewModelScope.launch` + `switchMap`. So "rapid same-key
/// dispatch → only the last effect reaches `reduce`" is structural, not luck.
public extension MviViewModel {
    /// Runs `operation` as a cancellable effect bound to `key`. Any running
    /// effect for `key` is cancelled first. The slot is cleared when *this*
    /// effect finishes (unless a newer `launch(key:)` has already replaced it).
    ///
    /// `operation` is `@MainActor`-isolated so it can drive ViewModel state
    /// (`reduce`, `handleError`, `emit`) directly — see the type doc comment.
    func launch(
        _ key: AnyHashable = "default",
        _ operation: @escaping @MainActor () async -> Void
    ) {
        effectTasks[key]?.cancel()

        let token = UUID()
        effectTokens[key] = token

        effectTasks[key] = Task { [weak self] in
            await operation()
            guard let self, effectTokens[key] == token else { return }
            effectTasks[key] = nil
            effectTokens[key] = nil
        }
    }

    /// Cancels and forgets every effect. Called by `onClear()`.
    func cancelEffects() {
        for task in effectTasks.values {
            task.cancel()
        }
        effectTasks.removeAll()
        effectTokens.removeAll()
    }
}
