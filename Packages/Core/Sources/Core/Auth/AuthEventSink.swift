/// Dependency-inversion seam for a 401. `Network` calls `onUnauthorized()`
/// without importing `Platform`; the composition root wires the concrete sink
/// into `AppEventBus`. `Sendable` — `Network` invokes it off the main actor.
public protocol AuthEventSink: AnyObject, Sendable {
    func onUnauthorized()
}
