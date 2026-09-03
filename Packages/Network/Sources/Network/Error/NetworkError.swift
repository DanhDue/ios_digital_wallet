import Core
import Foundation

/// Every failure mode `URLSessionAPIClient.send` can surface. Not `Equatable`
/// (the associated `Error` payloads are arbitrary); tests match on `case` and on
/// the mapped `AppError.code`.
public enum NetworkError: Error {
    /// A transport-layer failure that is not a timeout (DNS, offline, TLS, …).
    case transport(Error)
    /// The request exceeded its timeout.
    case timeout
    /// A `5xx` response. Carries the exact status code.
    case server(Int)
    /// A `4xx` response other than 401. Carries the exact status code.
    case client(Int)
    /// The body could not be decoded into the requested model.
    case decoding(Error)
    /// A `401` response. `URLSessionAPIClient` has already notified the
    /// `AuthEventSink` exactly once by the time this is thrown.
    case unauthorized
    /// The response was missing or was not an `HTTPURLResponse`.
    case invalidResponse

    /// Collapse to the single `AppError` the rest of the app carries. `code` is
    /// a stable, testable string; `underlying` keeps the raw description for
    /// diagnostics.
    public func asAppError() -> AppError {
        switch self {
        case let .transport(error):
            AppError(
                code: "transport",
                message: "Network request failed.",
                underlying: String(describing: error)
            )
        case .timeout:
            AppError(code: "timeout", message: "The request timed out.")
        case let .server(status):
            AppError(code: "server", message: "Server error (HTTP \(status)).", underlying: "HTTP \(status)")
        case let .client(status):
            AppError(code: "client", message: "Request rejected (HTTP \(status)).", underlying: "HTTP \(status)")
        case let .decoding(error):
            AppError(
                code: "decoding",
                message: "The response could not be read.",
                underlying: String(describing: error)
            )
        case .unauthorized:
            AppError(code: "unauthorized", message: "You are not signed in.", underlying: "HTTP 401")
        case .invalidResponse:
            AppError(code: "invalid_response", message: "The server returned an unexpected response.")
        }
    }
}
