import Foundation

/// Holds the current access token and refresh token. Class-bound so a single
/// instance is shared by reference across the graph; `Sendable` because
/// `Network` interceptors read it off the main actor.
public protocol SessionManaging: AnyObject, Sendable {
    var accessToken: String? { get }
    var refreshToken: String? { get }
    func update(accessToken: String?, refreshToken: String?)
    func clear()
}

public extension SessionManaging {
    /// Back-compat convenience for a routine access-token-only update. Forwards
    /// `refreshToken: nil`, which by the rotation rule leaves any existing
    /// refresh token untouched.
    func update(accessToken: String?) {
        update(accessToken: accessToken, refreshToken: nil)
    }
}

/// Default `SessionManaging`. Reads dominate writes; an `NSLock` gives
/// data-race safety without forcing callers through an `await`, hence
/// `@unchecked Sendable`. An optional `SecureCacheStore` mirrors both tokens to
/// persistent storage (Keychain in production); that store is not `Sendable`,
/// so every access to it — like every access to the token fields — happens
/// under the same `lock`, which upholds the guarantee the compiler can't
/// verify. With no store the manager is a pure in-memory store, byte-for-byte
/// as before.
public final class SessionManager: SessionManaging, @unchecked Sendable {
    private static let accessKey = "core.session.access"
    private static let refreshKey = "core.session.refresh"

    private let lock = NSLock()
    private let store: SecureCacheStore?
    private var token: String?
    private var refresh: String?

    /// - Parameters:
    ///   - accessToken: An explicit seed. When non-`nil` it wins over any value
    ///     already in `secureCacheStore` and is written through to it.
    ///   - secureCacheStore: Optional persistence. When present, `init` reloads
    ///     both tokens from it and every later mutation is mirrored to it.
    public init(accessToken: String? = nil, secureCacheStore: SecureCacheStore? = nil) {
        store = secureCacheStore
        refresh = secureCacheStore?.get(String.self, key: Self.refreshKey)
        if let accessToken {
            token = accessToken
            secureCacheStore?.set(accessToken, key: Self.accessKey)
        } else {
            token = secureCacheStore?.get(String.self, key: Self.accessKey)
        }
    }

    public var accessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    public var refreshToken: String? {
        lock.lock()
        defer { lock.unlock() }
        return refresh
    }

    public func update(accessToken: String?, refreshToken: String?) {
        lock.lock()
        defer { lock.unlock() }
        token = accessToken
        if let accessToken {
            store?.set(accessToken, key: Self.accessKey)
        } else {
            store?.remove(key: Self.accessKey)
        }
        // Rotation guard: only a non-`nil` refresh token replaces the stored one.
        // A routine access-only update (`refreshToken: nil`) leaves it intact.
        if let refreshToken {
            refresh = refreshToken
            store?.set(refreshToken, key: Self.refreshKey)
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        token = nil
        refresh = nil
        store?.remove(key: Self.accessKey)
        store?.remove(key: Self.refreshKey)
    }
}
