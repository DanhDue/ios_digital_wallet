import Foundation

/// The HTTP status codes the client branches on by name. Everything else is
/// classified by range (`2xx` success, `4xx` client, `5xx` server) in
/// `URLSessionAPIClient`.
public enum HTTPStatusCode: Int, Sendable {
    case noContent = 204
    case unauthorized = 401

    /// `true` for `200...299`.
    public static func isSuccess(_ code: Int) -> Bool {
        (200 ..< 300).contains(code)
    }

    /// `true` for `400...499`.
    public static func isClientError(_ code: Int) -> Bool {
        (400 ..< 500).contains(code)
    }

    /// `true` for `500...599`.
    public static func isServerError(_ code: Int) -> Bool {
        (500 ..< 600).contains(code)
    }
}
