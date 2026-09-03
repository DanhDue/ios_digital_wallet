/// The single error type carried by `DataState.error` across every layer.
///
/// `Sendable` so it can cross actor / task boundaries (e.g. inside a
/// `DataState` returned from an `actor`).
public struct AppError: Error, Equatable, Sendable {
    public let code: String
    public let message: String
    public let underlying: String?

    public init(code: String, message: String, underlying: String? = nil) {
        self.code = code
        self.message = message
        self.underlying = underlying
    }
}
