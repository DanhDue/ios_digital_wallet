import Foundation

/// Holds the current access token. Class-bound so a single instance is shared
/// by reference across the graph; `Sendable` because `Network` interceptors
/// read it off the main actor.
public protocol SessionManaging: AnyObject, Sendable {
    var accessToken: String? { get }
    func update(accessToken: String?)
    func clear()
}

/// Default `SessionManaging`. Reads dominate writes; an `NSLock` gives
/// data-race safety without forcing callers through an `await`, hence
/// `@unchecked Sendable` (the lock upholds the guarantee the compiler can't
/// verify).
public final class SessionManager: SessionManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(accessToken: String? = nil) {
        token = accessToken
    }

    public var accessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    public func update(accessToken: String?) {
        lock.lock()
        defer { lock.unlock() }
        token = accessToken
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        token = nil
    }
}
