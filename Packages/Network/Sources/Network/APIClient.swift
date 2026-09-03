import Core
import Foundation

/// An empty success payload. Use as `T` for `204 No Content` (or any endpoint
/// with no body).
public struct EmptyResponse: Decodable, Equatable, Sendable {
    public init() {}
}

/// The seam every Feature depends on. Features test against `MockAPIClient`; the
/// app wires `URLSessionAPIClient`.
public protocol APIClient: Sendable {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}

/// `URLSession`-backed `APIClient`. Runs interceptors in registration order,
/// maps transport / status failures to `NetworkError`, and — on a `401` — calls
/// `authEventSink.onUnauthorized()` **exactly once per response** before
/// throwing `NetworkError.unauthorized`.
///
/// `@unchecked Sendable`: `Logger` / `Environment` are injected values the
/// composition root guarantees are thread-safe; all other stored values are
/// `Sendable`.
public final class URLSessionAPIClient: APIClient, @unchecked Sendable {
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let environment: Environment
    private let logger: Logger
    private let authEventSink: AuthEventSink?
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        interceptors: [RequestInterceptor] = [],
        environment: Environment,
        logger: Logger,
        authEventSink: AuthEventSink? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.interceptors = interceptors
        self.environment = environment
        self.logger = logger
        self.authEventSink = authEventSink
        self.decoder = decoder
    }

    public func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        var urlRequest = try request.urlRequest(for: environment)
        for interceptor in interceptors {
            urlRequest = await interceptor.adapt(urlRequest)
        }
        try Task.checkCancellation()

        let (data, response) = try await perform(urlRequest)
        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        for interceptor in interceptors {
            interceptor.didReceive(http)
        }
        try validate(http, body: data)

        let payload = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try decoder.decode(T.self, from: payload)
        } catch {
            logError("decoding \(T.self) failed: \(error)", url: http.url, body: data)
            throw NetworkError.decoding(error)
        }
    }

    /// Run the transport, translating `URLError` into `NetworkError` /
    /// `CancellationError`.
    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError {
            switch urlError.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw NetworkError.timeout
            default: throw NetworkError.transport(urlError)
            }
        }
    }

    /// Throw the right `NetworkError` for a non-2xx response; a `401` also
    /// notifies the `AuthEventSink` exactly once.
    private func validate(_ http: HTTPURLResponse, body: Data) throws {
        let status = http.statusCode
        if HTTPStatusCode.isSuccess(status) {
            return
        }
        if status == HTTPStatusCode.unauthorized.rawValue {
            authEventSink?.onUnauthorized()
            logError("401 Unauthorized", url: http.url, body: body)
            throw NetworkError.unauthorized
        }
        logError("HTTP \(status)", url: http.url, body: body)
        if HTTPStatusCode.isClientError(status) {
            throw NetworkError.client(status)
        }
        if HTTPStatusCode.isServerError(status) {
            throw NetworkError.server(status)
        }
        throw NetworkError.invalidResponse
    }

    private func logError(_ summary: String, url: URL?, body: Data) {
        let location = url?.absoluteString ?? "<no url>"
        logger.error(
            "[Network] \(summary) for \(location) — body: \(Self.snippet(body))",
            file: #file,
            function: #function,
            line: #line
        )
    }

    private static func snippet(_ data: Data, limit: Int = 512) -> String {
        guard !data.isEmpty else { return "<empty>" }
        let text = String(bytes: data.prefix(limit), encoding: .utf8) ?? "<\(data.count) bytes>"
        return data.count > limit ? "\(text)…" : text
    }
}
