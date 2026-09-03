/// A FIFO buffer that an offline layer fills while disconnected and drains on
/// reconnect. An `actor` for data-race safety under concurrent producers.
///
/// The element constraint is `Codable & Sendable`: `Codable` is the design
/// contract (queued items are persistable); `Sendable` is required by Swift 6
/// strict concurrency because `enqueue` / `dequeueAll` cross the actor boundary.
public actor ReplayQueue<T: Codable & Sendable> {
    private var items: [T] = []

    public init() {}

    /// Appends one item to the tail.
    public func enqueue(_ item: T) {
        items.append(item)
    }

    /// Returns every buffered item in FIFO order and empties the queue. A second
    /// call with no intervening `enqueue` returns `[]`.
    public func dequeueAll() -> [T] {
        defer { items.removeAll() }
        return items
    }
}
