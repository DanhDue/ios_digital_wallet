import Foundation

/// HTTP verbs the client supports.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A type-erased `Encodable` body. The wrapped value must be `Sendable` so an
/// `APIRequest` can cross the actor hop into `URLSessionAPIClient` — in practice
/// bodies are value-type `Codable` structs, which satisfy this for free.
public struct AnyEncodable: Encodable, Sendable {
    private let encodeTo: @Sendable (Encoder) throws -> Void

    public init(_ wrapped: some Encodable & Sendable) {
        encodeTo = { encoder in try wrapped.encode(to: encoder) }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeTo(encoder)
    }
}

/// A transport-agnostic request description. `urlRequest(for:)` resolves it
/// against an `Environment` into a `URLRequest`.
public struct APIRequest: Sendable {
    public let method: HTTPMethod
    /// Path appended to `Environment.baseURL`. Leading slash optional; may be
    /// empty (request targets the base URL itself).
    public let path: String
    /// Query parameters. Encoded once, with reserved characters
    /// percent-escaped; emitted in sorted-key order for determinism.
    public let query: [String: String]
    /// Per-request headers. Override `Environment.defaultHeaders` on a name
    /// clash.
    public let headers: [String: String]
    /// Optional request body, JSON-encoded.
    public let body: AnyEncodable?

    public init(
        method: HTTPMethod,
        path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        body: AnyEncodable? = nil
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }

    /// Resolve against `environment` into a ready-to-send `URLRequest`:
    /// normalise the base/path join, percent-encode the query exactly once
    /// (sorted-key order), merge headers (per-request wins), and JSON-encode the
    /// body.
    public func urlRequest(for environment: Environment) throws -> URLRequest {
        var base = environment.baseURL.absoluteString
        while base.hasSuffix("/") {
            base.removeLast()
        }
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let joined = trimmedPath.isEmpty ? base : "\(base)/\(trimmedPath)"

        guard var components = URLComponents(string: joined) else {
            throw NetworkError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        for (name, value) in environment.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }
}
